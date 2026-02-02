import React, { useRef, useState } from 'react';
import { propsToCamelCase } from 'foremanReact/common/helpers';
import { isEqual } from 'lodash';
import { CVEDetailsBareCard } from '../../../../components/extensions/HostDetails/Cards/ContentViewDetailsCard/ContentViewDetailsCard';

const getAKDetailsFromDOM = (node) => {
  try {
    return propsToCamelCase(JSON.parse(node.dataset.akDetails));
  } catch (e) {
    return null;
  }
};
export const CVEDetailsCard = () => { // used as foreman-react-component, takes no props
  const akDetailsNode = useRef(document.getElementById('ak-cve-details')).current;
  const [akDetails, setAkDetails] = useState(getAKDetailsFromDOM(akDetailsNode));
  const observedAkDetailsAttributes = new Set([
    'id',
    'organization_id',
    'content_view_environments',
  ]);

  const observer = new MutationObserver((mutationsList) => {
    // eslint-disable-next-line no-restricted-syntax
    for (const mutation of mutationsList) {
      if (mutation.type === 'attributes' && mutation.attributeName.startsWith('data-')) {
        akDetailsNode.current = document.getElementById('ak-cve-details');
        const newDetails = getAKDetailsFromDOM(akDetailsNode);
        // eslint-disable-next-line no-restricted-syntax
        for (const key of Object.keys(newDetails)) {
          if (!isEqual(akDetails[key], newDetails[key]) && observedAkDetailsAttributes.has(key)) {
            setAkDetails(newDetails);
            return;
          }
        }
      }
    }
  });

  // Start observing akDetailsNode for attribute changes
  if (akDetailsNode) observer.observe(akDetailsNode, { attributes: true });

  if (!akDetails || !akDetails.contentViewEnvironments) return null;
  return (
    <CVEDetailsBareCard
      contentViewEnvironments={akDetails.contentViewEnvironments}
    />
  );
};

export default CVEDetailsCard;
