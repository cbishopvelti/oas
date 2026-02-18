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
  formData,
  errors,
  setFormData
}) => {

  const {data: trainingWhereTime} = useQuery(gql`
    query($training_where_id: Int!, $when: String!) {
      training_where_time_by_date(when: $when, training_where_id: $training_where_id){
        start_time,
        booking_offset,
        end_time
      }
    }
  `, {
    variables: {
      when: formData.when,
      training_where_id: formData.training_where?.id
    },
    skip: !formData.when || !formData.training_where?.id
  })

  useEffect(() => {
    console.log("101", formData.when, formData.training_where?.id)
    console.log("102", formData)


  }, [formData.when, formData.training_where?.id])

  console.log("103", trainingWhereTime)
  console.log("103.1", get(trainingWhereTime, 'training_where_time_by_date.booking_offset', ''))

  return <>
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <TextField
        id="start_time"
        label="Start time"
        value={get(formData, "start_time") || get(trainingWhereTime, 'training_where_time_by_date.start_time', '') || ''}
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
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <TextField
        id="booking_offset"
        label="Booking offset (iso 8601) (eg (-)P2DT15H (2 days, 15 hours))"
        value={get(formData, "booking_offset") || get(trainingWhereTime, 'training_where_time_by_date.booking_offset') || ''}
        type="schema"
        onChange={(event) => {
          let tmpFormData = formData
          if ( !get(formData, "start_time") && get(trainingWhereTime, 'training_where_time_by_date.start_time')) {

            tmpFormData.start_time = get(trainingWhereTime, 'training_where_time_by_date.start_time')
          }
          onChange({formData, setFormData, key: "booking_offset"})(event)
        }}
        InputLabelProps={{
          shrink: true,
        }}
        error={has(errors, "booking_offset")}
        helperText={get(errors, "booking_offset", []).join(" ")} />
    </FormControl>
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <TextField
        id="end_time"
        label="End time"
        value={get(formData, "end_time") || get(trainingWhereTime, 'training_where_time_by_date.end_time', '') || ''}
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
