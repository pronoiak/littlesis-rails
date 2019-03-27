import React from 'react';
import PropTypes from 'prop-types';

//  LODASH
import curry from 'lodash/curry';
import merge from 'lodash/merge';
import isPlainObject from 'lodash/isPlainObject';
import isNull from 'lodash/isNull';

// COMPONENTS
import ApiError from './components/ApiError';
import DatasetItemHeader from './components/DatasetItemHeader';
import DatasetItemInfo from './components/DatasetItemInfo';
import LoadingSpinner from './components/LoadingSpinner';
import PotentialMatches from './components/PotentialMatches';

// ACTIONS
import { loadItemInfo, loadMatches, ignoreMatch } from './actions';

// STATUS HELPERS
const LOADING = 'LOADING';
const COMPLETE = 'COMPLETE';
const ERROR = 'ERROR';

const defaultState = () => ({
  "itemId": null,
  "itemInfo": null,
  "itemInfoStatus": null,
  "matches": null,
  "matchesStatus": null,
  "datasetFields": []
});

export default class EntityMatcherUI extends React.Component {

  constructor(props) {
    super(props);
    this.state = merge(defaultState(), props);
    
    this.updateState = this.updateState.bind(this);
    
    
    // Actions
    // These functions essentially constitute the public API
    this.loadItemInfo = loadItemInfo.bind(this);
    this.loadMatches = loadMatches.bind(this);
    this.ignoreMatch = ignoreMatch.bind(this);
  }

  /**
   * I don't like how setState doesn't recursively merge objects. That's very annoying!
   * So my "updateState" uses lodash's merge to recursive combine the objects before sending
   * them to setState. Yes, I could use redux or something, but I'll stick with this function 
   * until I feel like that's needed.
   *
   * Additionally, It allows a second synatx for updating the state:
   *   updateState(key, value)
   * which is the same as updateState({ key: value })
   */
  updateState(newStateOrKey, value) {
    if (isPlainObject(newStateOrKey)) {
      this.setState( (state, props) => merge({}, state, newStateOrKey) );
    } else {
      this.setState( (state, props) => merge({}, state, { [newStateOrKey]: value }) );
    }
  }

  componentDidMount() {
    if (!this.state.itemInfo) {
      this.loadItemInfo(this.state.itemId);
    }

    if (isNull(this.state.matchesStatus)) {
      this.loadMatches(this.state.itemId);
    }
  }

  render() {
    const itemInfoLoading = this.state.itemInfoStatus === LOADING;
    const itemInfoComplete = this.state.itemInfoStatus === COMPLETE;
    const itemInfoError = this.state.itemInfoStatus === ERROR;

    return(
      <div id="entity-matcher-ui">
        <div className="leftSide">
          { itemInfoLoading && <LoadingSpinner /> }
          { itemInfoError && <ApiError /> }
          {
            itemInfoComplete &&
            <>
              <DatasetItemHeader itemId={this.state.itemId}  />
              <DatasetItemInfo itemInfo={this.state.itemInfo} datasetFields={this.state.datasetFields} />
            </>
          }
        </div>
        <div className="rightSide">
          <PotentialMatches
            ignoreMatch={this.ignoreMatch}
            matches={this.state.matches}
            matchesStatus={this.state.matchesStatus}
          />
        </div>
      </div>
    );
  }
}

EntityMatcherUI.propTypes = {
  "itemId": PropTypes.oneOfType([ PropTypes.string, PropTypes.number]).isRequired,
  "datasetFields": PropTypes.array.isRequired
};