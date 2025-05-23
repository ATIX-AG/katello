import React from 'react';
import { renderWithRedux, patientlyWaitFor, fireEvent, act } from 'react-testing-lib-wrapper';

import { nockInstance, assertNockRequest } from '../../../../test-utils/nockWrapper';
import api from '../../../../services/api';
import CreateContentViewForm from '../CreateContentViewForm';
import cvCreateData from './contentViewCreateResult.fixtures.json';

const cvCreatePath = api.getApiUrl('/content_views');

const mockFn = jest.fn();

delete window.location;
window.location = { assign: mockFn };

afterEach(() => {
  mockFn.mockClear();
});

const createDetails = {
  name: '1232123',
  label: '1232123',
  description: '',
  composite: false,
  rolling: false,
  solve_dependencies: false,
  auto_publish: false,
};

const createdCVDetails = { ...cvCreateData };

const form = <CreateContentViewForm setModalOpen={mockFn} />;

test('Can save content view from form', async (done) => {
  const createscope = nockInstance
    .post(cvCreatePath, createDetails)
    .reply(201, createdCVDetails);
  const { queryByText, getByLabelText } = renderWithRedux(form);
  expect(queryByText('Description')).toBeInTheDocument();

  fireEvent.change(getByLabelText('input_name'), { target: { value: '1232123' } });

  await patientlyWaitFor(() => { expect(getByLabelText('input_label')).toHaveAttribute('value', '1232123'); });

  getByLabelText('create_content_view').click();

  assertNockRequest(createscope);
  done();
});

test('Form closes itself upon save', async (done) => {
  const createscope = nockInstance
    .post(cvCreatePath, createDetails)
    .reply(201, createdCVDetails);
  const { getByText, getByLabelText } = renderWithRedux(form);
  expect(getByText('Description')).toBeInTheDocument();
  expect(getByText('Name')).toBeInTheDocument();
  expect(getByText('Label')).toBeInTheDocument();

  fireEvent.change(getByLabelText('input_name'), { target: { value: '1232123' } });

  await patientlyWaitFor(() => { expect(getByLabelText('input_label')).toHaveAttribute('value', '1232123'); });
  jest.spyOn(window.location, 'assign');
  getByLabelText('create_content_view').click();
  // Form closes it self on success by calling location.assign()
  await patientlyWaitFor(() => {
    expect(window.location.assign).toHaveBeenCalled();
  });

  assertNockRequest(createscope);
  done();
});

test('Displays dependent fields correctly', () => {
  const { getByText, queryByText, getByLabelText } = renderWithRedux(form);
  expect(getByText('Description')).toBeInTheDocument();
  expect(getByText('Name')).toBeInTheDocument();
  expect(getByText('Label')).toBeInTheDocument();
  expect(getByText('Composite content view')).toBeInTheDocument();
  expect(getByText('Content view')).toBeInTheDocument();
  expect(getByText('Rolling content view')).toBeInTheDocument();
  expect(getByText('Solve dependencies')).toBeInTheDocument();
  expect(queryByText('Auto publish')).not.toBeInTheDocument();

  // label auto_set
  fireEvent.change(getByLabelText('input_name'), { target: { value: '123 2123' } });
  expect(getByLabelText('input_label')).toHaveAttribute('value', '123_2123');

  // display Auto Publish when Composite CV
  fireEvent.click(getByLabelText('composite_tile'));
  expect(queryByText('Solve dependencies')).not.toBeInTheDocument();
  expect(getByText('Auto publish')).toBeInTheDocument();

  // display Solve Dependencies when Component CV
  fireEvent.click(getByLabelText('component_tile'));
  expect(getByText('Solve dependencies')).toBeInTheDocument();
  expect(queryByText('Auto publish')).not.toBeInTheDocument();
});

test('Validates label field', () => {
  const { getByText, getByLabelText } = renderWithRedux(form);
  expect(getByText('Label')).toBeInTheDocument();

  act(() => {
    fireEvent.change(getByLabelText('input_label'), { target: { value: '123 2123' } });
  });
  expect(getByText('Must be Ascii alphanumeric, \'_\' or \'-\'')).toBeInTheDocument();
});
