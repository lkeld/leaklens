mod leak_check_proto {
    include!(concat!(env!("OUT_DIR"), "/google.internal.identity.passwords.leak.check.v1.rs"));
}

pub use leak_check_proto::LookupSingleLeakRequest;
pub use leak_check_proto::LookupSingleLeakResponse;