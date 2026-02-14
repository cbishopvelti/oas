import { useEffect, useState } from 'react';
import { get, omit, has, assign } from 'lodash';
import { Box, Stack, Alert, FormControl,
  TextField, Button, FormControlLabel, Switch } from '@mui/material'
import { gql, useQuery } from '@apollo/client';

const onChange = ({ formData, setFormData, key, isCheckbox }) => (event) => {
  if (isCheckbox) {
    setFormData({
      ...formData,
      [key]: event.target.checked
    })
    return;
  }
  setFormData({
    ...formData,
    [key]: !event.target.value ? null : event.target.value
  })
}

export const TrainingFormBilling = ({
  formData,
  setFormData,
  errors
}) => {
  const [billingOverride, setBillingOverride] = useState(false);

  const { data: venueData, loading: venueLoading } = useQuery(gql`query ($id: Int!) {
    training_where(id: $id) {
      billing_type
    }
  }`, {
    variables: {
      id: get(formData, "training_where.id")
    },
    skip: !get(formData, "training_where.id")
  })

  const { data: billingAmount } = useQuery(gql(`query (
    $training_id: Int,
    $training_where_id: Int!,
    $when: String!
  ) {
    training_billing_amount
  }`, {
    variables: {
      training_id: formData.id,
      training_where_id: get(formData, "training_where.id"),
      when: formData.when
    },
    skip: !get(formData, "training_where.id") || !formData.when || billingOverride
  }))

  useEffect(() => {
    if (!venueLoading) {
      setBillingOverride(!!get(formData, "venue_billing_override"))
    }
  }, [get(formData, "venue_billing_override"), venueLoading])

  useEffect(() => {
    if (get(formData, "venue_billing_override") && !billingOverride) {
      onChange({
        formData,
        setFormData,
        key: "venue_billing_override"
      })({
        target: {
          value: null
        }
      })
    }
  }, [billingOverride])

  useEffect(() => {
    onChange({
      formData,
      setFormData,
      key: "venue_billing_enabled",
      isCheckbox: true
    })({
      target: {
        checked: !!get(venueData, 'training_where.billing_type', false)
      }
    })

    if (!venueLoading && get(venueData, "training_where.billing_type") !== get(formData, "training_where.billing_type")) {
      onChange({
        formData,
        setFormData,
        key: "venue_billing_override"
      })({
        target: {
          value: null
        }
      })
    }
  }, [get(venueData, "training_where.billing_type")])

  return get(venueData, 'training_where.billing_type', false) && <>
    <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
      <FormControlLabel
        control={
          <Switch
            checked={get(formData, "venue_billing_enabled", false) || false}
            onChange={onChange({ formData: formData, setFormData, key: "venue_billing_enabled", isCheckbox: true })}
          />}
        label="Venue billing enabled"
        title="If this event will be added to the venues billing account."
      />
    </FormControl>

    <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
      <FormControlLabel
        control={
          <Switch
            checked={billingOverride}
            onChange={(event) => event.target.checked ? setBillingOverride(true) : setBillingOverride(false)}
          />}
        label="Override Venue billing"
        title="Override the calculated billing amount"
      />
    </FormControl>

    {
      <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <TextField
          id="billing-override"
          label={`Billing ${billingOverride ? 'override' : 'amount'}`}
          type="text"
          disabled={!billingOverride}
          value={get(formData, "venue_billing_override", '') || ''}
          onChange={
            onChange({formData, setFormData, key: "venue_billing_override"})
          }
          inputMode="numeric"
          pattern="[0-9\.]*"
          error={has(errors, "venue_billing_override")}
          helperText={get(errors, "venue_billing_override", []).join(" ")}
        />
      </FormControl>
    }
  </>
}
