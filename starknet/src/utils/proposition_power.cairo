use starknet::{ContractAddress, info};
use sx::interfaces::{
    IProposalValidationStrategy, IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait
};
use sx::types::{UserAddress, IndexedStrategy, IndexedStrategyTrait, Strategy};
use sx::utils::BitSetter;

// Proposal validation strategy specific version of `get_cumulative_power` function from the space contract.
// The difference is that this function takes a span  of `allowed_strategies` instead of an uint256.
fn get_cumulative_power(
    voter: UserAddress,
    timestamp: u32,
    mut user_strategies: Span<IndexedStrategy>,
    allowed_strategies: Span<Strategy>,
) -> u256 {
    user_strategies.assert_no_duplicate_indices();
    let mut total_voting_power = 0_u256;
    loop {
        match user_strategies.pop_front() {
            Option::Some(indexed_strategy) => {
                match allowed_strategies.get((*indexed_strategy.index).into()) {
                    Option::Some(strategy) => {
                        let strategy: Strategy = strategy.unbox().clone();
                        total_voting_power +=
                            IVotingStrategyDispatcher { contract_address: strategy.address }
                            .get_voting_power(
                                timestamp,
                                voter,
                                strategy.params.span(),
                                indexed_strategy.params.span(),
                            );
                    },
                    Option::None => { panic_with_felt252('Invalid strategy index'); },
                };
            },
            Option::None => { break total_voting_power; },
        };
    }
}

/// See `ProposingPowerProposalValidationStrategy` for more information.
fn validate(
    author: UserAddress,
    mut params: Span<felt252>, // [proposal_threshold: u256, allowed_strategies: Array<Strategy>]
    mut user_params: Span<felt252> // [user_strategies: Array<IndexedStrategy>]
) -> bool {
    let (proposal_threshold, allowed_strategies) = Serde::<
        (u256, Array<Strategy>)
    >::deserialize(ref params)
        .unwrap();

    let user_strategies = Serde::<Array<IndexedStrategy>>::deserialize(ref user_params).unwrap();

    let timestamp: u32 = info::get_block_timestamp().try_into().unwrap() - 1;
    let voting_power = get_cumulative_power(
        author, timestamp, user_strategies.span(), allowed_strategies.span()
    );
    voting_power >= proposal_threshold
}

