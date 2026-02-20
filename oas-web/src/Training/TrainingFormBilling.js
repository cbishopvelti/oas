import { useEffect, useState } from 'react';
import { get, omit, has, assign, set, cloneDeep } from 'lodash';
import { Box, Stack, Alert, FormControl,
  TextField, Button, FormControlLabel, Switch } from '@mui/material'
import { gql, useQuery } from '@apollo/client';
import { VenueBilling } from '../Venue/VenueBilling';

const onChange = ({ formData, setFormData, key, isCheckbox }) => (event) => {
  if (isCheckbox) {
    setFormData(
      set(cloneDeep(formData), key, event.target.checked)
    )
    return;
  }

  setFormData(
    set(cloneDeep(formData), key, !event.target.value ? null : event.target.value)
  )
}

export const TrainingFormBilling = ({
  data,
  formData,
  setFormData,
  errors,
  trainingWhereTime,
  attendanceAcc
}) => {
  const [billingEnabled, setBillingEnabled] = useState(false)

  const { data: venueData, loading: venueLoading } = useQuery(gql`query ($id: Int!) {
    training_where(id: $id) {
      id
      billing_type
      billing_config
    }
  }`, {
    variables: {
      id: get(formData, "training_where.id")
    },
    skip: !get(formData, "training_where.id")
  })

  const setBillingEnabledAction = (event) => { // Billing Enabeld, set the config to the venue/training_where config
    const billingEnabled = event.target.checked;
    if (billingEnabled) {
      setFormData((formData) => {
        return {
          ...formData,
          venue_billing_type: get(venueData, "training_where.billing_type"),
          venue_billing_config: get(venueData, "training_where.billing_config")
        }
      })
    } else {
      setFormData((formData) => {
        return {
          ...formData,
          venue_billing_type: null,
          venue_billing_config: null
        }
      })
    }
  }
  useEffect(() => { // venue_billing_type changed to null, so billing enabled false
    if (!get(formData, "venue_billing_type")) {
      setBillingEnabled(false)
    } else {
      setBillingEnabled(true)
    }
  }, [get(formData, "venue_billing_type")])
  useEffect(() => { // Venue changed, set config to the new venue
    if (get(formData, "training_where.id") !== get(data, "training.training_where.id")) {
      setFormData((formData) => {
        return {
          ...formData,
          venue_billing_type: get(venueData, "training_where.billing_type"),
          venue_billing_config: get(venueData, "training_where.billing_config")
        }
      })
      if (get(venueData, "training_where.billing_type")) {
        setBillingEnabled(true)
      }
    }
  }, [get(venueData, "training_where.id"), get(formData, "training_where.id")])

  return <>
    <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
      <FormControlLabel
        control={
          <Switch
            checked={billingEnabled}
            onChange={setBillingEnabledAction}
          />}
        label="Venue billing enabled"
        title="If this event will be added to the venues billing account."
      />
    </FormControl>
    {billingEnabled && <VenueBilling prefix={"venue_"} onChange={onChange} formData={formData} setFormData={setFormData} errors={errors} />}
  </>
}
