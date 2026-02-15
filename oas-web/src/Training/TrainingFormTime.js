import { gql, useQuery } from '@apollo/client';
import { Box, Stack, Alert, FormControl,
  TextField, Button, FormControlLabel, Switch } from '@mui/material'
import { get, has} from 'lodash'
import { useEffect } from 'react';

const onChange = ({formData, setFormData, key, isCheckbox}) => (event) => {
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

export const TrainingFormTime = ({
  data,
  formData,
  errors,
  setFormData,
  trainingWhereTime
}) => {


  useEffect(() => {
    if (get(formData, "training_where.id") !== get(data, "training.training_where.id")) {
      setFormData({
        ...formData,
        start_time: get(trainingWhereTime, 'training_where_time_by_date.start_time'),
        end_time: get(trainingWhereTime, 'training_where_time_by_date.end_time'),
        booking_offset: get(trainingWhereTime, 'training_where_time_by_date.booking_offset')
      })
    }
  }, [trainingWhereTime])

  return <>
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <TextField
        id="start_time"
        label="Start time"
        required={get(formData, "training_where.billing_type") === "PER_HOUR"}
        value={get(formData, "start_time") || ''}
        type="time"
        onChange={
          onChange({formData, setFormData, key: "start_time"})
        }
        InputLabelProps={{
          shrink: true,
        }}
        error={has(errors, "start_time")}
        helperText={get(errors, "start_time", []).join(" ")}
        />
    </FormControl>
    {!get(formData, 'commitment', false) && <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
      <TextField
        id="booking_offset"
        label="Booking offset (iso 8601) (eg (-)P2DT15H (2 days, 15 hours))"
        value={get(formData, "booking_offset") || get(trainingWhereTime, 'training_where_time_by_date.booking_offset') || ''}
        type="schema"
        onChange={(event) => {
          let tmpFormData = formData
          if (!get(formData, "start_time") && get(trainingWhereTime, 'training_where_time_by_date.start_time')) {

            tmpFormData.start_time = get(trainingWhereTime, 'training_where_time_by_date.start_time')
          }
          onChange({ formData, setFormData, key: "booking_offset" })(event)
        }}
        InputLabelProps={{
          shrink: true,
        }}
        error={has(errors, "booking_offset")}
        helperText={get(errors, "booking_offset", []).join(" ")} />
    </FormControl>}
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <TextField
        id="end_time"
        label="End time"
        required={get(formData, "training_where.billing_type") === "PER_HOUR"}
        value={get(formData, "end_time") || ''}
        type="time"
        onChange={
          onChange({formData, setFormData, key: "end_time"})
        }
        InputLabelProps={{
          shrink: true,
        }}
        error={has(errors, "end_time")}
        helperText={get(errors, "end_time", []).join(" ")}
        />
    </FormControl>
  </>
}
