import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PropTypes from 'prop-types';
import { Tooltip } from '@patternfly/react-core';
import { CubesIcon, EnterpriseIcon, RegistryIcon } from '@patternfly/react-icons';
import './contentViewIcon.scss';

const ContentViewIcon = ({
  composite, rolling, count, description, style, ...toolTipProps
}) => {
  const props = {
    className: composite ? 'svg-icon-composite' : (rolling ? 'svg-icon-rolling' : 'svg-icon-component'),
  };
  const cvIcon = (
    <Tooltip
      position="auto"
      enableFlip
      entryDelay={400}
      content={composite ? __('Composite content view') : (rolling ? __('Rolling content view') : __('Content view'))}
      {...toolTipProps}
    >
      {composite ? <RegistryIcon size="md" {...props} /> : (rolling ? <CubesIcon size="sm" {...props} /> : <EnterpriseIcon size="sm" {...props} />)}
    </Tooltip>
  );
  return (
    <div aria-label="content_view_icon" className="svg-centered-container" style={style}>
      {count && <span className="composite-component-count">{count}</span>}
      {cvIcon}
      <span>{description}</span>
    </div>
  );
};

ContentViewIcon.propTypes = {
  composite: PropTypes.bool,
  rolling: PropTypes.bool,
  count: PropTypes.node,
  description: PropTypes.node,
  style: PropTypes.shape({}),
};

ContentViewIcon.defaultProps = {
  composite: false,
  rolling: false,
  count: null,
  description: null,
  style: {},
};

export default ContentViewIcon;
