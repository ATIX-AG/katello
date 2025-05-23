import React, { useContext, useState } from 'react';
import useDeepCompareEffect from 'use-deep-compare-effect';
import { Alert, Checkbox, EmptyState, EmptyStateVariant, EmptyStateBody, AlertActionCloseButton, EmptyStateHeader } from '@patternfly/react-core';
import { TableVariant, Table /* data-codemods */, Thead, Tbody, Tr, Th, Td } from '@patternfly/react-table';
import { translate as __ } from 'foremanReact/common/I18n';
import DeleteContext from '../DeleteContext';

const CVEnvironmentSelectionForm = () => {
  const [alertDismissed, setAlertDismissed] = useState(false);
  const {
    versionNameToRemove, versionEnvironments, selectedEnvSet,
    setAffectedActivationKeys, setAffectedHosts, deleteFlow,
    removeDeletionFlow, setRemoveDeletionFlow,
  } = useContext(DeleteContext);

  const areAllSelected = () => versionEnvironments.every(env => selectedEnvSet.has(env.id));

  const onSelect = (_event, isSelected, rowId) => {
    if (isSelected) {
      selectedEnvSet.add(rowId);
    } else {
      selectedEnvSet.delete(rowId);
    }
  };

  // Based on env selected for removal, decide if we need to reassign hosts and activation keys.
  useDeepCompareEffect(() => {
    const selectedEnvironments = versionEnvironments.filter(env => selectedEnvSet.has(env.id));

    const needsHostReassignment = selectedEnvironments.some(env =>
      (env.host_count || 0) > (env.multi_env_host_count || 0));
    setAffectedHosts(needsHostReassignment);

    const needsAKReassignment = selectedEnvironments.some(env =>
      (env.activation_key_count || 0) > (env.multi_env_ak_count || 0));
    setAffectedActivationKeys(needsAKReassignment);
  }, [setAffectedActivationKeys, setAffectedHosts,
    versionEnvironments, selectedEnvSet, selectedEnvSet.size]);

  const onSelectAll = (event, isSelected) => {
    if (!isSelected) {
      setRemoveDeletionFlow(false);
      selectedEnvSet.clear();
    } else {
      versionEnvironments.forEach(env => selectedEnvSet.add(env.id));
    }
  };

  const columnHeaders = [
    __('Environment'),
    __('Hosts'),
    __('Activation keys'),
  ];

  const versionDeleteInfo = __(`Version ${versionNameToRemove} will be deleted from the listed environments. It will no longer be available for promotion.`);
  const versionRemovalInfo = __('Removing this version from all environments will not delete the version. Version will still be available for later promotion.');
  const versionEnvironmentsEmptyInfo = __(`Version ${versionNameToRemove} has not been promoted to any environments. ` +
    'You can delete this version completely and it will no longer be available for promotion.');
  return (
    <>
      {!alertDismissed && deleteFlow &&
        <Alert
          ouiaId="delete-version-info-alert"
          variant="warning"
          isInline
          title={__('Warning')}
          actionClose={<AlertActionCloseButton onClose={() => setAlertDismissed(true)} />}
        >
          <p style={{ marginBottom: '0.5em' }}>{versionDeleteInfo}</p>
        </Alert>
      }
      {(!deleteFlow &&
        (removeDeletionFlow || areAllSelected() || versionEnvironments.length === 0))
        && (
          <Alert variant="warning" isInline title={__('Warning')} ouiaId="delete-version-alert">
            <p style={{ marginBottom: '0.5em' }}>{removeDeletionFlow ? versionDeleteInfo : versionRemovalInfo}</p>
            <Checkbox
              ouiaId="delete-version-checkbox"
              id="delete_version"
              label={__('Delete version')}
              isChecked={removeDeletionFlow}
              onChange={(_event, checked) => setRemoveDeletionFlow(checked)}
              style={{ margin: 0 }}
            />
          </Alert>)}
      {(versionEnvironments.length !== 0) &&
        <Table ouiaId="version-delete-env-table" variant={TableVariant.compact}>
          <Thead>
            <Tr ouiaId="version-delete-env-table-header">
              <Td
                select={{
                  rowIndex: 0,
                  onSelect: onSelectAll,
                  isSelected: areAllSelected() || deleteFlow || removeDeletionFlow,
                  isDisabled: deleteFlow || removeDeletionFlow,
                }}
              />
              {columnHeaders.map(col =>
                <Th key={col}>{col}</Th>)}
            </Tr>
          </Thead>
          <Tbody>
            {versionEnvironments?.map(({
              id, name, activation_key_count: akCount,
              host_count: hostCount,
            }, rowIndex) =>
              (
                <Tr ouiaId={`${name}_${id}`} key={`${name}_${id}`}>
                  <Td
                    key={`${name}__${id}_select`}
                    select={{
                      rowIndex,
                      onSelect: (event, isSelected) => onSelect(event, isSelected, id),
                      isSelected: selectedEnvSet.has(id) || deleteFlow || removeDeletionFlow,
                      isDisabled: deleteFlow || removeDeletionFlow,
                    }}
                  />
                  <Td>
                    {name}
                  </Td>
                  <Td>{hostCount}</Td>
                  <Td>{akCount}</Td>
                </Tr>
              ))
            }
          </Tbody>
        </Table>}
      {(versionEnvironments.length === 0) &&
        <EmptyState variant={EmptyStateVariant.xs}>
          <EmptyStateHeader titleText={<>{__('This version has not been promoted to any environments.')}</>} headingLevel="h4" />
          <EmptyStateBody>
            {versionEnvironmentsEmptyInfo}
          </EmptyStateBody>
        </EmptyState>}
    </>
  );
};

export default CVEnvironmentSelectionForm;
