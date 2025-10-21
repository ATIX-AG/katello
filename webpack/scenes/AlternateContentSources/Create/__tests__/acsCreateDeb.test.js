import React from 'react';
import * as reactRedux from 'react-redux';
import { Route } from 'react-router-dom';
import { act, fireEvent, patientlyWaitFor, renderWithRedux } from 'react-testing-lib-wrapper';
import api, { foremanApi } from '../../../../services/api';
import { assertNockRequest, mockAutocomplete, nockInstance } from '../../../../test-utils/nockWrapper';
import ACSTable from '../../MainTable/ACSTable';
import contentCredentialResult from './contentCredentials.fixtures';
import smartProxyResult from './smartProxy.fixtures';
import productsResult from './products.fixtures.json';

const withACSRoute = component => <Route path="/alternate_content_sources/">{component}</Route>;
const ACSIndexPath = api.getApiUrl('/alternate_content_sources');
const ACSCreatePath = api.getApiUrl('/alternate_content_sources');
const contentCredentialPath = api.getApiUrl('/content_credentials');
const smartProxyPath = foremanApi.getApiUrl('/smart_proxies');
const productsPath = api.getApiUrl('/products');
const autocompleteUrl = '/alternate_content_sources/auto_complete_search';

const createDebACSDetails = {
  upstream_username: 'username',
  upstream_password: 'password',
  name: 'acs_deb_test',
  description: '',
  base_url: 'https://deb.example.org/',
  subpaths: ['dists/bookworm/main/binary-amd64', 'pool/main/'],
  smart_proxy_names: ['centos7-katello-devel-stable.example.com'],
  content_type: 'deb',
  alternate_content_source_type: 'custom',
  verify_ssl: false,
  use_http_proxies: false,
  ssl_ca_cert_id: '',
};

test('Can display create wizard and create custom Deb ACS', async (done) => {
  const autocompleteScope = mockAutocomplete(nockInstance, autocompleteUrl);
  const scope = nockInstance
    .get(ACSIndexPath)
    .query(true)
    .times(2)
    .reply(200, noResults);

  const contentCredentialScope = nockInstance
    .get(contentCredentialPath)
    .query(true)
    .reply(200, contentCredentialResult);

  const smartProxyScope = nockInstance
    .get(smartProxyPath)
    .query(true)
    .reply(200, smartProxyResult);

  const createScope = nockInstance
    .post(ACSCreatePath, createDebACSDetails)
    .reply(201, { id: 23 });

  const { getLabelText, getByText, getAllByRole, queryByText } =
    renderWithRedux(withACSRoute(<ACSTable />), renderOptions);

  await patientlyWaitFor(() => 
    expect(queryByText("You currently don't have any alternate content sources.")).toBeInTheDocument()
  );
  fireEvent.click(getByText('Add source'));

  await patientlyWaitFor(() => 
    expect(getByText('Add an alternate content source')).toBeInTheDocument()
  );

  fireEvent.click(getByText('Custom'));
  fireEvent.change(getByLabelText('FormSelect Input'), { target: { value: 'deb' } });
  fireEvent.click(getByText('Next'));

  fireEvent.change(getByLabelText('acs_name_field'), { target: { value: 'acs_deb_test' } });

  const useSmartProxySelectorMock = jest.spyOn(reactRedux, 'useSelector');
  useSmartProxySelectorMock.mockReturnValue(smartProxyResult);
  fireEvent.click(getByText('Next'));
  await patientlyWaitFor(() =>
    expect(getByText('centos7-katello-devel-stable.example.com')).toBeInTheDocument()
  );
  fireEvent.click(getByLabelText('Add all'));
  useSmartProxySelectorMock.mockRestore();
  fireEvent.click(getByText('Next'));

  fireEvent.change(getByLabelText('acs_base_url_field'), { target: { value: 'https://deb.example.org/' } });
  fireEvent.change(getByLabelText('acs_subpath_field'), {
    target: { value: 'dists/bookworm/main/binary-amd64/,pool/main/' },
  });

  const useContentCredentialSelectorMock = jest.spyOn(reactRedux, 'useSelector');
  useContentCredentialSelectorMock.mockReturnValue(contentCredentialResult.results);
  fireEvent.click(getByText('Next'));
  const manualAuthRadio = getAllByRole('radio', { name: 'Manual authentication' })[0];
  fireEvent.click(manualAuthRadio);
  fireEvent.change(getByLabelText('acs_username_field'), { target: { value: 'username' } });
  fireEvent.change(getByLabelText('acs_password_field'), { target: { value: 'password' } });
  useContentCredentialSelectorMock.mockRestore();

  fireEvent.click(getByText('Next'));
  fireEvent.click(getAllByRole('button', { name: 'Add' })[0]);

  assertNockRequest(autocompleteScope);
  assertNockRequest(scope);
  assertNockRequest(contentCredentialScope);
  assertNockRequest(smartProxyScope);
  assertNockRequest(createScope);
  done();
  act(done);
})
