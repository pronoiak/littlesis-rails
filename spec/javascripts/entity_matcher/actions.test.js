// import React from 'react';

import * as actions from 'packs/entity_matcher/actions';

beforeEach(() => fetch.resetMocks());

describe('resultsWithoutEntity', () => {
  const results = [
    { "entity": { "id": 1, name: 'one'} },
    { "entity": { "id": 2, name: 'two'} },
    { "entity": { "id": 3, name: 'three'} }
  ];

  test('It removes entity with 2 from array', () => {
    expect(actions.resultsWithoutEntity(results, 2))
      .toEqual([
	{ "entity": { "id": 1, name: 'one'} },
	{ "entity": { "id": 3, name: 'three'} }
      ]);
  });

});

describe('doMatch', () => {
  test('updates matches before and afte request', async () => {
    document.head.innerHTML = '<meta name="csrf-token" content="abcd">';
    
    fetch.mockResponseOnce(JSON.stringify({ "status": 'OK', "results": ['owner_not_matched'] }));

    let mockBindingObject = { "updateState": jest.fn() };
    await actions.doMatch.call(mockBindingObject, 123, 456);

    expect(fetch.mock.calls[0][0]).toEqual('/external_datasets/row/123/match');
    expect(mockBindingObject.updateState.mock.calls.length).toEqual(2);
    expect(mockBindingObject.updateState.mock.calls[0]).toEqual(['matchedState', 'MATCHING']);
    expect(mockBindingObject.updateState.mock.calls[1]).toEqual([ {
      "matchedState": 'MATCHED',
      "matchResult": ['owner_not_matched']
    }]);
  });
});
