use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, MintTo, Burn, Transfer};

declare_id!("SovXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");

/// Maximum SOV token supply: 1,000,000,000 (1 billion)
pub const MAX_SUPPLY: u64 = 1_000_000_000 * 10u64.pow(9);
/// Token decimals
pub const DECIMALS: u8 = 9;

#[program]
pub mod sov_token {
    use super::*;

    /// Initialize the SOV token and protocol state
    pub fn initialize(
        ctx: Context<Initialize>,
        initial_mint_amount: u64,
    ) -> Result<()> {
        let state = &mut ctx.accounts.protocol_state;
        state.authority = ctx.accounts.authority.key();
        state.mint = ctx.accounts.mint.key();
        state.total_staked = 0;
        state.total_earned = 0;
        state.reward_rate = 100; // 100 SOV per resource unit per epoch

        // Mint initial supply to treasury
        if initial_mint_amount > 0 {
            let cpi_accounts = MintTo {
                mint: ctx.accounts.mint.to_account_info(),
                to: ctx.accounts.treasury.to_account_info(),
                authority: ctx.accounts.authority.to_account_info(),
            };
            let cpi_ctx = CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                cpi_accounts,
            );
            token::mint_to(cpi_ctx, initial_mint_amount)?;
        }

        emit!(TokenInitialized {
            mint: ctx.accounts.mint.key(),
            authority: ctx.accounts.authority.key(),
            initial_supply: initial_mint_amount,
        });

        Ok(())
    }

    /// Register a node to earn SOV tokens for DePIN contributions
    pub fn register_node(
        ctx: Context<RegisterNode>,
        tier: NodeTier,
        node_id: [u8; 32],
    ) -> Result<()> {
        let node = &mut ctx.accounts.node_account;
        node.owner = ctx.accounts.owner.key();
        node.tier = tier.clone();
        node.node_id = node_id;
        node.total_earned = 0;
        node.total_staked = 0;
        node.last_claim_epoch = Clock::get()?.epoch;
        node.is_active = true;
        node.contribution_points = 0;

        emit!(NodeRegistered {
            owner: ctx.accounts.owner.key(),
            tier,
            node_id,
        });

        Ok(())
    }

    /// Record resource contribution and accrue SOV rewards
    /// Called by authorized oracles reporting DePIN node activity
    pub fn record_contribution(
        ctx: Context<RecordContribution>,
        bandwidth_mb: u64,
        storage_gb: u64,
        compute_units: u64,
    ) -> Result<()> {
        let node = &mut ctx.accounts.node_account;
        require!(node.is_active, SovError::NodeInactive);

        let state = &ctx.accounts.protocol_state;

        // Calculate contribution points based on tier multiplier
        let tier_multiplier = match node.tier {
            NodeTier::Min    => 1u64,
            NodeTier::Medium => 2u64,
            NodeTier::Max    => 5u64,
        };

        let points = (bandwidth_mb / 1024
            + storage_gb * 10
            + compute_units * 100)
            * tier_multiplier;

        node.contribution_points = node.contribution_points.saturating_add(points);

        // Calculate SOV reward
        let sov_reward = points
            .checked_mul(state.reward_rate)
            .ok_or(SovError::ArithmeticOverflow)?;

        node.pending_rewards = node.pending_rewards.saturating_add(sov_reward);
        node.total_earned = node.total_earned.saturating_add(sov_reward);

        emit!(ContributionRecorded {
            node: ctx.accounts.node_account.key(),
            bandwidth_mb,
            storage_gb,
            compute_units,
            sov_reward,
        });

        Ok(())
    }

    /// Claim accumulated SOV rewards
    pub fn claim_rewards(ctx: Context<ClaimRewards>) -> Result<()> {
        let node = &mut ctx.accounts.node_account;
        require!(node.is_active, SovError::NodeInactive);
        require!(node.pending_rewards > 0, SovError::NoPendingRewards);

        let rewards = node.pending_rewards;
        node.pending_rewards = 0;
        node.last_claim_epoch = Clock::get()?.epoch;

        // Mint rewards to the node owner's token account
        let seeds = &[
            b"protocol_state",
            &[ctx.bumps.protocol_state],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = MintTo {
            mint: ctx.accounts.mint.to_account_info(),
            to: ctx.accounts.owner_token_account.to_account_info(),
            authority: ctx.accounts.protocol_state.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer,
        );
        token::mint_to(cpi_ctx, rewards)?;

        emit!(RewardsClaimed {
            owner: ctx.accounts.owner.key(),
            amount: rewards,
        });

        Ok(())
    }

    /// Stake SOV tokens for governance rights and tier bonuses
    pub fn stake(ctx: Context<Stake>, amount: u64) -> Result<()> {
        require!(amount > 0, SovError::InvalidAmount);

        let node = &mut ctx.accounts.node_account;
        let state = &mut ctx.accounts.protocol_state;

        // Transfer from owner to staking vault
        let cpi_accounts = Transfer {
            from: ctx.accounts.owner_token_account.to_account_info(),
            to: ctx.accounts.staking_vault.to_account_info(),
            authority: ctx.accounts.owner.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
        );
        token::transfer(cpi_ctx, amount)?;

        node.total_staked = node.total_staked.saturating_add(amount);
        state.total_staked = state.total_staked.saturating_add(amount);

        emit!(TokensStaked {
            owner: ctx.accounts.owner.key(),
            amount,
            total_staked: node.total_staked,
        });

        Ok(())
    }

    /// Unstake SOV tokens
    pub fn unstake(ctx: Context<Unstake>, amount: u64) -> Result<()> {
        let node = &mut ctx.accounts.node_account;
        require!(node.total_staked >= amount, SovError::InsufficientStake);

        let state = &mut ctx.accounts.protocol_state;

        let seeds = &[
            b"staking_vault",
            &[ctx.bumps.staking_vault],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.staking_vault.to_account_info(),
            to: ctx.accounts.owner_token_account.to_account_info(),
            authority: ctx.accounts.staking_vault.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer,
        );
        token::transfer(cpi_ctx, amount)?;

        node.total_staked = node.total_staked.saturating_sub(amount);
        state.total_staked = state.total_staked.saturating_sub(amount);

        emit!(TokensUnstaked {
            owner: ctx.accounts.owner.key(),
            amount,
        });

        Ok(())
    }

    /// Pay for AI compute using SOV tokens
    pub fn pay_for_compute(
        ctx: Context<PayForCompute>,
        amount: u64,
        job_id: [u8; 32],
    ) -> Result<()> {
        require!(amount > 0, SovError::InvalidAmount);

        // Transfer from payer to compute provider
        let cpi_accounts = Transfer {
            from: ctx.accounts.payer_token_account.to_account_info(),
            to: ctx.accounts.provider_token_account.to_account_info(),
            authority: ctx.accounts.payer.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
        );
        token::transfer(cpi_ctx, amount)?;

        emit!(ComputePayment {
            payer: ctx.accounts.payer.key(),
            provider: ctx.accounts.provider.key(),
            amount,
            job_id,
        });

        Ok(())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accounts
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + ProtocolState::LEN,
        seeds = [b"protocol_state"],
        bump,
    )]
    pub protocol_state: Account<'info, ProtocolState>,

    #[account(
        init,
        payer = authority,
        mint::decimals = DECIMALS,
        mint::authority = authority,
        mint::freeze_authority = authority,
    )]
    pub mint: Account<'info, Mint>,

    #[account(
        init_if_needed,
        payer = authority,
        associated_token::mint = mint,
        associated_token::authority = authority,
    )]
    pub treasury: Account<'info, TokenAccount>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct RegisterNode<'info> {
    #[account(
        init,
        payer = owner,
        space = 8 + NodeAccount::LEN,
        seeds = [b"node", owner.key().as_ref()],
        bump,
    )]
    pub node_account: Account<'info, NodeAccount>,

    #[account(mut)]
    pub owner: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RecordContribution<'info> {
    #[account(mut)]
    pub node_account: Account<'info, NodeAccount>,

    #[account(seeds = [b"protocol_state"], bump)]
    pub protocol_state: Account<'info, ProtocolState>,

    /// Oracle authorized to report contributions
    pub oracle: Signer<'info>,
}

#[derive(Accounts)]
pub struct ClaimRewards<'info> {
    #[account(
        mut,
        seeds = [b"node", owner.key().as_ref()],
        bump,
        has_one = owner,
    )]
    pub node_account: Account<'info, NodeAccount>,

    #[account(
        mut,
        seeds = [b"protocol_state"],
        bump,
    )]
    pub protocol_state: Account<'info, ProtocolState>,

    #[account(mut)]
    pub mint: Account<'info, Mint>,

    #[account(mut)]
    pub owner_token_account: Account<'info, TokenAccount>,

    pub owner: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Stake<'info> {
    #[account(
        mut,
        seeds = [b"node", owner.key().as_ref()],
        bump,
        has_one = owner,
    )]
    pub node_account: Account<'info, NodeAccount>,

    #[account(
        mut,
        seeds = [b"protocol_state"],
        bump,
    )]
    pub protocol_state: Account<'info, ProtocolState>,

    #[account(mut)]
    pub owner_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        seeds = [b"staking_vault"],
        bump,
    )]
    pub staking_vault: Account<'info, TokenAccount>,

    pub owner: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Unstake<'info> {
    #[account(
        mut,
        seeds = [b"node", owner.key().as_ref()],
        bump,
        has_one = owner,
    )]
    pub node_account: Account<'info, NodeAccount>,

    #[account(
        mut,
        seeds = [b"protocol_state"],
        bump,
    )]
    pub protocol_state: Account<'info, ProtocolState>,

    #[account(mut)]
    pub owner_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        seeds = [b"staking_vault"],
        bump,
    )]
    pub staking_vault: Account<'info, TokenAccount>,

    pub owner: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct PayForCompute<'info> {
    #[account(mut)]
    pub payer_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub provider_token_account: Account<'info, TokenAccount>,

    /// CHECK: Provider pubkey for event emission only
    pub provider: AccountInfo<'info>,

    pub payer: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

#[account]
pub struct ProtocolState {
    pub authority: Pubkey,      // 32
    pub mint: Pubkey,           // 32
    pub total_staked: u64,      // 8
    pub total_earned: u64,      // 8
    pub reward_rate: u64,       // 8
}

impl ProtocolState {
    pub const LEN: usize = 32 + 32 + 8 + 8 + 8;
}

#[account]
pub struct NodeAccount {
    pub owner: Pubkey,              // 32
    pub tier: NodeTier,             // 1
    pub node_id: [u8; 32],         // 32
    pub total_earned: u64,          // 8
    pub total_staked: u64,          // 8
    pub pending_rewards: u64,       // 8
    pub last_claim_epoch: u64,      // 8
    pub is_active: bool,            // 1
    pub contribution_points: u64,   // 8
}

impl NodeAccount {
    pub const LEN: usize = 32 + 1 + 32 + 8 + 8 + 8 + 8 + 1 + 8;
}

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq, Eq)]
pub enum NodeTier {
    Min,
    Medium,
    Max,
}

// ─────────────────────────────────────────────────────────────────────────────
// Events
// ─────────────────────────────────────────────────────────────────────────────

#[event]
pub struct TokenInitialized {
    pub mint: Pubkey,
    pub authority: Pubkey,
    pub initial_supply: u64,
}

#[event]
pub struct NodeRegistered {
    pub owner: Pubkey,
    pub tier: NodeTier,
    pub node_id: [u8; 32],
}

#[event]
pub struct ContributionRecorded {
    pub node: Pubkey,
    pub bandwidth_mb: u64,
    pub storage_gb: u64,
    pub compute_units: u64,
    pub sov_reward: u64,
}

#[event]
pub struct RewardsClaimed {
    pub owner: Pubkey,
    pub amount: u64,
}

#[event]
pub struct TokensStaked {
    pub owner: Pubkey,
    pub amount: u64,
    pub total_staked: u64,
}

#[event]
pub struct TokensUnstaked {
    pub owner: Pubkey,
    pub amount: u64,
}

#[event]
pub struct ComputePayment {
    pub payer: Pubkey,
    pub provider: Pubkey,
    pub amount: u64,
    pub job_id: [u8; 32],
}

// ─────────────────────────────────────────────────────────────────────────────
// Errors
// ─────────────────────────────────────────────────────────────────────────────

#[error_code]
pub enum SovError {
    #[msg("Node is inactive")]
    NodeInactive,
    #[msg("No pending rewards to claim")]
    NoPendingRewards,
    #[msg("Invalid amount")]
    InvalidAmount,
    #[msg("Insufficient staked amount")]
    InsufficientStake,
    #[msg("Arithmetic overflow")]
    ArithmeticOverflow,
    #[msg("Unauthorized")]
    Unauthorized,
}
