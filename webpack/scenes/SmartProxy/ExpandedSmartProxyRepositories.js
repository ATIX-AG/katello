/* eslint-disable react/no-array-index-key */
import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { DataList, DataListItem, DataListItemRow, DataListItemCells, DataListCell } from '@patternfly/react-core';
import AdditionalCapsuleContent from './AdditionalCapsuleContent';
import InactiveText from '../ContentViews/components/InactiveText';
import RepoIcon from '../ContentViews/Details/Repositories/RepoIcon';

const ExpandedSmartProxyRepositories = ({
  contentCounts, repositories, syncedToCapsule, envId,
}) => {
  const filterDataByEnvId = () => {
    const filteredData = {};

    Object.keys(contentCounts).forEach((key) => {
      const entry = contentCounts[key];
      if (entry.metadata.env_id === envId) {
        filteredData[key] = entry;
      }
    });
    return filteredData;
  };
  const envContentCounts = filterDataByEnvId();

  const getRepositoryNameById = id => (repositories.find(repo =>
    Number(repo.id) === Number(id) || Number(repo.library_id) === Number(id)) || {}).name;

  const dataListCellLists = (repoCounts, repo) => {
    const cellList = [];
    /* eslint-disable max-len */
    cellList.push(<DataListCell key={`${repo.id}-name`}><span><a href={`/products/${envContentCounts[repo].metadata.product_id}/repositories/${envContentCounts[repo].metadata.library_instance_id}/`}>{getRepositoryNameById(envContentCounts[repo].metadata.library_instance_id)}</a></span></DataListCell>);
    cellList.push(<DataListCell key={`${repo.id}-type`}><RepoIcon type={envContentCounts[repo].metadata.content_type} identifier={repo.id} /></DataListCell>);
    cellList.push(<DataListCell key={`${repo.id}-rpm`}><span>{envContentCounts[repo].counts.rpm ? `${envContentCounts[repo].counts.rpm} ${__('Packages')}` : 'N/A'}</span></DataListCell>);
    cellList.push(<DataListCell key={`${repo.id}-count`}><AdditionalCapsuleContent counts={envContentCounts[repo].counts} /></DataListCell>);
    /* eslint-enable max-len */
    return cellList;
  };

  const dataListCellListsNotSynced = (repo) => {
    const cellList = [];
    /* eslint-disable max-len */
    cellList.push(<DataListCell key={`${repo.id}-name`}><span><a href={`/products/${repo.product_id}/repositories/${repo.library_id || repo.id}/`}>{repo.name}</a></span></DataListCell>);
    cellList.push(<DataListCell key={`${repo.id}-type`}><RepoIcon type={repo.content_type} identifier={repo.id} /></DataListCell>);
    cellList.push(<DataListCell key={`${repo.id}-rpm`}><span><InactiveText text="N/A" /></span></DataListCell>);
    cellList.push(<DataListCell key={`${repo.id}-count`}><InactiveText text="N/A" /></DataListCell>);
    /* eslint-enable max-len */
    return cellList;
  };

  const getDataListItems = () => {
    if (Object.keys(envContentCounts).length) {
      return Object.keys(envContentCounts).map((repo, index) => (
        <DataListItem key={`${repo.id}-${index}`}>
          <DataListItemRow>
            <DataListItemCells
              dataListCells={dataListCellLists(envContentCounts[repo], repo)}
            />
          </DataListItemRow>
        </DataListItem>
      ));
    }

    if (repositories?.length) {
      return repositories.map((repo, index) => (
        <DataListItem key={`${repo.id}-${index}`}>
          <DataListItemRow>
            <DataListItemCells
              dataListCells={dataListCellListsNotSynced(repo)}
            />
          </DataListItemRow>
        </DataListItem>
      ));
    }

    return (
      <DataListItem key="empty">
        <DataListItemRow>
          <DataListItemCells
            dataListCells={[<DataListCell key="cv-empty"><InactiveText text={__('Content view version is empty')} /></DataListCell>]}
          />
        </DataListItemRow>
      </DataListItem>
    );
  };

  const getUnsyncedRepositoriesDataListItems = () => {
    const countedRepoLibraryIds = Object.values(envContentCounts).map(count =>
      count.metadata.library_instance_id);
    const repositoriesNotSynced = repositories.filter(repo =>
      !countedRepoLibraryIds.includes(repo.library_id || repo.id));
    if (repositoriesNotSynced?.length) {
      return repositoriesNotSynced.map((repo, index) => {
        if (!envContentCounts[repo.id]) {
          return (
            <DataListItem key={`${repo.id}-${index}`}>
              <DataListItemRow>
                <DataListItemCells
                  dataListCells={dataListCellListsNotSynced(repo)}
                />
              </DataListItemRow>
            </DataListItem>
          );
        }
        return <></>;
      });
    }
    return <></>;
  };

  if (syncedToCapsule === 'partial') {
    return (
      <DataList aria-label="Expanded repository details" isCompact>
        <DataListItem key="headers" >
          <DataListItemRow>
            <DataListItemCells dataListCells={[
              <DataListCell key="primary content">
                <b>{__('Repository')}</b>
              </DataListCell>,
              <DataListCell key="Type"><b>{__('Type')}</b></DataListCell>,
              <DataListCell key="Package count"><b>{__('Packages')}</b></DataListCell>,
              <DataListCell key="Additional content"><b>{__('Additional content')}</b></DataListCell>,
            ]}
            />
          </DataListItemRow>
        </DataListItem>
        {getDataListItems()}
        {getUnsyncedRepositoriesDataListItems()}
      </DataList>
    );
  }

  if (syncedToCapsule) {
    return (
      <DataList aria-label="Expanded repository details" isCompact>
        <DataListItem key="headers" >
          <DataListItemRow>
            <DataListItemCells dataListCells={[
              <DataListCell key="primary content">
                <b>{__('Repository')}</b>
              </DataListCell>,
              <DataListCell key="Type"><b>{__('Type')}</b></DataListCell>,
              <DataListCell key="Package count"><b>{__('Packages')}</b></DataListCell>,
              <DataListCell key="Additional content"><b>{__('Additional content')}</b></DataListCell>,
            ]}
            />
          </DataListItemRow>
        </DataListItem>
        {getDataListItems()}
      </DataList>
    );
  }

  return (
    <DataList aria-label="Expanded repository details" isCompact>
      <DataListItem key="headers" >
        <DataListItemRow>
          <DataListItemCells dataListCells={[
            <DataListCell key="primary content">
              <b>{__('Repository')}</b>
            </DataListCell>,
            <DataListCell key="Type"><b>{__('Type')}</b></DataListCell>,
            <DataListCell key="Package count"><b>{__('Packages')}</b></DataListCell>,
            <DataListCell key="Additional content"><b>{__('Additional content')}</b></DataListCell>,
          ]}
          />
        </DataListItemRow>
      </DataListItem>
      {repositories.length ?
        repositories.map((repo, index) => (
          <DataListItem key={`${repo.id}-${index}`}>
            <DataListItemRow>
              <DataListItemCells dataListCells={dataListCellListsNotSynced(repo)} />
            </DataListItemRow>
          </DataListItem>
        )) :
        <DataListItem key="empty">
          <DataListItemRow>
            <DataListItemCells
              dataListCells={[<DataListCell key="cv-empty"><InactiveText text={__('Content view version is empty or content counts are not up to date')} /></DataListCell>]}
            />
          </DataListItemRow>
        </DataListItem>
    }
    </DataList>);
};

ExpandedSmartProxyRepositories.propTypes = {
  contentCounts: PropTypes.shape({}),
  repositories: PropTypes.arrayOf(PropTypes.shape({})),
  syncedToCapsule: PropTypes.oneOfType([
    PropTypes.bool,
    PropTypes.string, // The API can return true/false or 'partial' for partially synced CVs
  ]),
  envId: PropTypes.oneOfType([
    PropTypes.number,
    PropTypes.string, // The API can sometimes return strings
  ]).isRequired,
};

ExpandedSmartProxyRepositories.defaultProps = {
  contentCounts: {},
  repositories: [{}],
  syncedToCapsule: false,
};

export default ExpandedSmartProxyRepositories;
