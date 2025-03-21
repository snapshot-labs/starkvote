#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, info, testing};
    use sx::interfaces::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::space::space::Space;
    use sx::tests::setup::setup::setup::{setup, deploy, Config};
    use sx::types::UpdateSettingsCalldata;
    use sx::tests::utils::strategy_trait::{StrategyImpl, StrategyDefault};
    use openzeppelin::tests::utils;
    use sx::space::space::Space::{
        MinVotingDurationUpdated, MaxVotingDurationUpdated, VotingDelayUpdated, MetadataUriUpdated,
        DaoUriUpdated, ProposalValidationStrategyUpdated, AuthenticatorsAdded,
        AuthenticatorsRemoved, VotingStrategiesAdded, VotingStrategiesRemoved,
    };

    fn setup_update_settings() -> (Config, ISpaceDispatcher) {
        let config = setup();
        let (_, space) = deploy(@config);
        utils::drop_events(space.contract_address, 3);

        testing::set_caller_address(config.owner);
        testing::set_contract_address(config.owner);

        (config, space)
    }

    fn assert_correct_event<
        T, impl TPartialEq: PartialEq<T>, impl TDrop: Drop<T>, impl TEvent: starknet::Event<T>
    >(
        space_address: ContractAddress, expected: T
    ) {
        let event = utils::pop_log::<T>(space_address).unwrap();
        assert(event == expected, 'event\'s content incorrect');
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn update_unauthorized() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();

        testing::set_contract_address(starknet::contract_address_const::<'unauthorized'>());
        space.update_settings(input);
    }

    #[test]
    #[available_gas(10000000000)]
    fn update_min_voting_duration() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.min_voting_duration = config.min_voting_duration + 1;

        space.update_settings(input.clone());

        assert(
            space.min_voting_duration() == input.min_voting_duration,
            'Min voting duration not updated'
        );
        let expected_event = Space::Event::MinVotingDurationUpdated(
            MinVotingDurationUpdated { min_voting_duration: input.min_voting_duration }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected_event);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))]
    fn update_min_voting_duration_too_big() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.min_voting_duration = config.max_voting_duration + 1;

        space.update_settings(input.clone());
    }


    #[test]
    #[available_gas(10000000000)]
    fn update_max_voting_duration() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.max_voting_duration = config.max_voting_duration + 1;

        space.update_settings(input.clone());

        assert(
            space.max_voting_duration() == input.max_voting_duration,
            'Max voting duration not updated'
        );
        let expected_event = Space::Event::MaxVotingDurationUpdated(
            MaxVotingDurationUpdated { max_voting_duration: input.max_voting_duration }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected_event);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))]
    fn update_max_voting_duration_too_small() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.max_voting_duration = config.min_voting_duration - 1;

        space.update_settings(input.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    fn update_min_max_voting_duration_at_once() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.min_voting_duration = config.max_voting_duration + 1;
        input.max_voting_duration = config.max_voting_duration + 2;

        space.update_settings(input.clone());
        assert(
            space.min_voting_duration() == input.min_voting_duration,
            'Min voting duration not updated'
        );
        assert(
            space.max_voting_duration() == input.max_voting_duration,
            'Max voting duration not updated'
        );

        let expected_event = Space::Event::MinVotingDurationUpdated(
            MinVotingDurationUpdated { min_voting_duration: input.min_voting_duration }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected_event);

        let expected_event = Space::Event::MaxVotingDurationUpdated(
            MaxVotingDurationUpdated { max_voting_duration: input.max_voting_duration }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected_event);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))]
    fn update_min_max_voting_duration_at_once_invalid() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.min_voting_duration = config.max_voting_duration + 1;
        input
            .max_voting_duration = config
            .max_voting_duration; // min is bigger than max, should fail

        space.update_settings(input.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    fn update_voting_delay() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.voting_delay = config.voting_delay + 1;

        space.update_settings(input.clone());

        assert(space.voting_delay() == input.voting_delay, 'Voting delay not updated');
        let expected = Space::Event::VotingDelayUpdated(
            VotingDelayUpdated { voting_delay: input.voting_delay }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    fn metadata_uri() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        let mut arr = array![];
        'hello!'.serialize(ref arr);
        input.metadata_uri = arr;

        space.update_settings(input.clone());
        let expected = Space::Event::MetadataUriUpdated(
            MetadataUriUpdated { metadata_uri: input.metadata_uri.span() }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    fn dao_uri() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        input.dao_uri = array!['hello!'];

        space.update_settings(input.clone());
        assert(space.dao_uri() == input.dao_uri, 'dao uri not updated');
        let expected = Space::Event::DaoUriUpdated(DaoUriUpdated { dao_uri: input.dao_uri.span() });
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    fn proposal_validation_strategy() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        let randomStrategy = StrategyImpl::from_address(
            starknet::contract_address_const::<'randomStrategy'>()
        );
        input.proposal_validation_strategy = randomStrategy;
        let mut arr = array![];
        'hello!'.serialize(ref arr);
        input.proposal_validation_strategy_metadata_uri = arr;

        space.update_settings(input.clone());

        assert(
            space.proposal_validation_strategy() == input.proposal_validation_strategy,
            'Proposal strategy not updated'
        );
        let expected = Space::Event::ProposalValidationStrategyUpdated(
            ProposalValidationStrategyUpdated {
                proposal_validation_strategy: input.proposal_validation_strategy,
                proposal_validation_strategy_metadata_uri: input
                    .proposal_validation_strategy_metadata_uri
                    .span()
            }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    fn add_authenticators() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        let auth1 = starknet::contract_address_const::<'authenticator1'>();
        let auth2 = starknet::contract_address_const::<'authenticator2'>();
        let mut arr = array![auth1, auth2];
        input.authenticators_to_add = arr;

        space.update_settings(input.clone());

        assert(space.authenticators(auth1) == true, 'Authenticator 1 not added');
        assert(space.authenticators(auth2) == true, 'Authenticator 2 not added');

        let expected = Space::Event::AuthenticatorsAdded(
            AuthenticatorsAdded { authenticators: input.authenticators_to_add.span() }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    fn remove_authenticators() {
        let (config, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();
        let auth1 = *config.authenticators.at(0);
        let mut arr = array![auth1];
        input.authenticators_to_remove = arr;

        space.update_settings(input.clone());

        assert(space.authenticators(auth1) == false, 'Authenticator not removed');
        let expected = Space::Event::AuthenticatorsRemoved(
            AuthenticatorsRemoved { authenticators: input.authenticators_to_remove.span() }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    fn add_voting_strategies() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();

        let vs1 = StrategyImpl::from_address(
            starknet::contract_address_const::<'votingStrategy1'>()
        );
        let vs2 = StrategyImpl::from_address(
            starknet::contract_address_const::<'votingStrategy2'>()
        );

        let mut arr = array![vs1.clone(), vs2.clone()];
        input.voting_strategies_to_add = arr;
        input.voting_strategies_metadata_uris_to_add = array![array![], array![]];

        space.update_settings(input.clone());

        assert(space.voting_strategies(1) == vs1, 'Voting strategy 1 not added');
        assert(space.voting_strategies(2) == vs2, 'Voting strategy 2 not added');
        assert(space.active_voting_strategies() == 0b111, 'Voting strategies not active');

        let expected = Space::Event::VotingStrategiesAdded(
            VotingStrategiesAdded {
                voting_strategies: input.voting_strategies_to_add.span(),
                voting_strategy_metadata_uris: input.voting_strategies_metadata_uris_to_add.span(),
            }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('len mismatch', 'ENTRYPOINT_FAILED'))]
    fn add_voting_strategies_mismatch() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();

        let vs1 = StrategyImpl::from_address(
            starknet::contract_address_const::<'votingStrategy1'>()
        );
        let vs2 = StrategyImpl::from_address(
            starknet::contract_address_const::<'votingStrategy2'>()
        );

        let mut arr = array![vs1.clone(), vs2.clone()];
        input.voting_strategies_to_add = arr;
        input.voting_strategies_metadata_uris_to_add = array![array![]]; // missing one uri!

        space.update_settings(input.clone());

        assert(space.voting_strategies(1) == vs1, 'Voting strategy 1 not added');
        assert(space.voting_strategies(2) == vs2, 'Voting strategy 2 not added');
        assert(space.active_voting_strategies() == 0b111, 'Voting strategies not active');
    }


    #[test]
    #[available_gas(10000000000)]
    fn remove_voting_strategies() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();

        // First, add a new voting strategy
        let vs1 = StrategyImpl::from_address(
            starknet::contract_address_const::<'votingStrategy1'>()
        );
        let mut arr = array![vs1.clone()];
        input.voting_strategies_to_add = arr;
        input.voting_strategies_metadata_uris_to_add = array![array![]];
        space.update_settings(input);
        assert(space.voting_strategies(1) == vs1, 'Voting strategy 1 not added');
        assert(space.active_voting_strategies() == 0b11, 'Voting strategy not active');

        // Drop the event that just got emitted
        utils::drop_event(space.contract_address);

        // Now, remove the first voting strategy
        let mut input: UpdateSettingsCalldata = Default::default();
        let mut arr = array![0];
        input.voting_strategies_to_remove = arr;

        space.update_settings(input.clone());
        assert(space.active_voting_strategies() == 0b10, 'strategy not removed');

        let expected = Space::Event::VotingStrategiesRemoved(
            VotingStrategiesRemoved {
                voting_strategy_indices: input.voting_strategies_to_remove.span()
            }
        );
        assert_correct_event::<Space::Event>(space.contract_address, expected);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('No active voting strategy left', 'ENTRYPOINT_FAILED'))]
    fn remove_all_voting_strategies() {
        let (_, space) = setup_update_settings();
        let mut input: UpdateSettingsCalldata = Default::default();

        // Remove the first voting strategy
        let mut arr = array![0];
        input.voting_strategies_to_remove = arr;

        space.update_settings(input);
    }
}
