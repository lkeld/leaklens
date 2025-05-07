use governor::{
    clock::DefaultClock,
    state::{InMemoryState, NotKeyed},
    Quota, RateLimiter as GovernorRateLimiter,
};
use std::num::NonZeroU32;
use std::sync::OnceLock;
use std::time::Duration;

use crate::utils::config;

struct RateLimitSettings {
    single_credential_limit: NonZeroU32,
    batch_credentials_limit: NonZeroU32,
}

impl RateLimitSettings {
    fn new() -> Self {
        let cfg = config::get();
        
        RateLimitSettings {
            single_credential_limit: NonZeroU32::new(cfg.rate_limits.single_credential_rpm).unwrap_or(NonZeroU32::new(60).unwrap()),
            batch_credentials_limit: NonZeroU32::new(cfg.rate_limits.batch_credential_rpm).unwrap_or(NonZeroU32::new(10).unwrap()),
        }
    }
}

static SETTINGS: OnceLock<RateLimitSettings> = OnceLock::new();

fn settings() -> &'static RateLimitSettings {
    SETTINGS.get_or_init(RateLimitSettings::new)
}

pub struct RateLimiter {
    single_credential_limiter: GovernorRateLimiter<NotKeyed, InMemoryState, DefaultClock>,
    batch_credentials_limiter: GovernorRateLimiter<NotKeyed, InMemoryState, DefaultClock>,
}

impl RateLimiter {
    pub fn new() -> Self {
        let settings = settings();

        let single_credential_limiter = GovernorRateLimiter::direct(
            Quota::with_period(Duration::from_secs(60))
                .unwrap()
                .allow_burst(settings.single_credential_limit),
        );

        let batch_credentials_limiter = GovernorRateLimiter::direct(
            Quota::with_period(Duration::from_secs(60))
                .unwrap()
                .allow_burst(settings.batch_credentials_limit),
        );

        RateLimiter {
            single_credential_limiter,
            batch_credentials_limiter,
        }
    }

    pub async fn check_single_credential_limit(&self) -> bool {
        self.single_credential_limiter.check().is_ok()
    }

    pub async fn check_batch_credentials_limit(&self) -> bool {
        self.batch_credentials_limiter.check().is_ok()
    }
}

static RATE_LIMITER: OnceLock<RateLimiter> = OnceLock::new();

pub fn get_rate_limiter() -> &'static RateLimiter {
    RATE_LIMITER.get_or_init(RateLimiter::new)
}