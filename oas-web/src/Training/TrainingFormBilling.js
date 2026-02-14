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
  errors,
  trainingWhereTime,
  attendanceAcc
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

  const { data: billingAmount, refetch: billingAmountRefetch } = useQuery(gql`query (
    $training_id: Int,
    $training_where_id: Int!,
    $start_time: String,
    $end_time: String
  ) {
    training_billing_amount(training_id: $training_id, training_where_id: $training_where_id,
      start_time: $start_time,
      end_time: $end_time
    )
  }`, {
    variables: {
      training_id: formData.id,
      training_where_id: get(formData, "training_where.id"),
      start_time: get(formData, "start_time") || get(trainingWhereTime, 'training_where_time_by_date.start_time'),
      end_time: get(formData, "end_time") || get(trainingWhereTime, 'training_where_time_by_date.end_time')
    },
    skip: !get(formData, "training_where.id") ||
      (get(formData, "training_where.billing_type") === "PER_HOUR" && !formData.when) ||
      billingOverride,
  })

  useEffect(() => {
    if (get(formData, "training_where.id")) {
      billingAmountRefetch()
    }
  }, [attendanceAcc, formData])

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
          value={billingOverride ? (get(formData, "venue_billing_override", '') || '') :
            billingAmount?.training_billing_amount || ''
          }
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
