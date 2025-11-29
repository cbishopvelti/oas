import { useEffect, useState } from "react";
import { gql, useQuery, useMutation } from "@apollo/client";
import { useNavigate, useParams, useOutletContext, Link } from "react-router-dom";
import { Box, FormControl, TextField, Button, Switch, FormControlLabel,
  InputLabel, Select, MenuItem,
  FormHelperText
} from "@mui/material";
import { get, has, range} from 'lodash'
import { TimeField } from '@mui/x-date-pickers/TimeField';
import DurationPicker from "./Duration";
import CustomDurationField from "./Duration";
import { parseErrors } from "../utils/util";

export const dayToString = (dayOfWeek) => {
  switch (dayOfWeek) {
    case 1:
      return "Monday";
    case 2:
      return "Tuesday"
    case 3:
      return "Wednesday"
    case 4:
      return "Thursday"
    case 5:
      return "Friday"
    case 6:
      return "Saturday"
    case 7:
      return "Sunday"
    default:
      return null
  }
}

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
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const VenueTime = () => {
  const { setTitle } = useOutletContext();
  const navigate = useNavigate();
  let {
    training_where_id,
    id
  } = useParams()
  const [formData, setFormData] = useState({})

  const { data: trainingWhereData } = useQuery(gql`
    query($training_where_id: Int!) {
      training_where(id: $training_where_id) {
        id,
        name
      }
    }
  `, {
    variables: {
      training_where_id: parseInt(training_where_id)
    }
  })
  useEffect(() => {
    setTitle(`Time for: ${trainingWhereData?.training_where?.name}`)
  }, [id, trainingWhereData])

  const { data } = useQuery(gql`
    query($id: Int!) {
      training_where_time(id: $id) {
        day_of_week
        start_time,
        booking_offset,
        end_time,
        recurring
      }
    }
  `,{
    variables: {
      id: parseInt(id)
    },
    skip: !id
  })

  useEffect(() => {
    setFormData(get(data, "training_where_time"))
  }, [data])

  const [mutation, {error}] = useMutation(gql`
    mutation($id: Int, $day_of_week: Int, $training_where_id: Int!, $start_time: String!, $booking_offset: String, $end_time: String, $recurring: Boolean) {
      training_where_time(
        id: $id,
        training_where_id: $training_where_id,
        day_of_week: $day_of_week,
        start_time: $start_time,
        booking_offset: $booking_offset,
        end_time: $end_time,
        recurring: $recurring
      ) {
        id
      }
    }
    `)
  const errors = parseErrors(error?.graphQLErrors);

  const save = (formData) => async () => {
    try {
      const { data } = await mutation({
        variables: {
          ...((id) ? { id: parseInt(id) } : {}),
          training_where_id: parseInt(training_where_id),
          day_of_week: parseInt(formData.day_of_week),
          start_time: formData.start_time,
          booking_offset: formData.booking_offset,
          end_time: formData.end_time,
          recurring: formData.recurring
        }
      })
      if (get(data, 'training_where_time.id')) {
        navigate(`/venue-time/${training_where_id}/${get(data, 'training_where_time.id')}`)
      }
    } catch (err) {
      console.error(err)
    }
  }

  return <Box sx={{m: 2}}>
    <FormControl fullWidth sx={{mt: 2,mb: 2}}>
      <InputLabel required id="day-of-week">Day of the week</InputLabel>
      <Select
        label="Day of the week"
        value={get(formData, "day_of_week", '') || ''}
        onChange={onChange({formData, setFormData, key: "day_of_week"})}
        error={has(errors, "day_of_week")}
        id="day-of-week">
        <MenuItem value="">&nbsp;</MenuItem>
        {
          range(1, 8).map((day_of_week, id) => {
            return <MenuItem key={id} value={day_of_week}>
              {dayToString(day_of_week)}
            </MenuItem>
          })
        }
      </Select>
      {has(errors, "day_of_week") && <FormHelperText error={true}>
        {get(errors, "day_of_week", []).join(" ")}
      </FormHelperText>}
    </FormControl>
    <FormControl fullWidth sx={{mt:2, mb: 2}}>
      <TextField
        required
        type="time"
        label="Start time"
        value={get(formData, "start_time", '') || ''}
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
      <CustomDurationField
        label="Booking cutoff offset relative to start time."
        value={get(formData, "booking_offset", '') || ''}
        onChange={
          onChange({formData, setFormData, key: "booking_offset"})
        }
      />
    </FormControl>
    <FormControl fullWidth sx={{mt:2, mb:2}}>
      <TextField
        type="time"
        label="End time"
        value={get(formData, "end_time", '') || ''}
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
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <FormControlLabel
        control={
          <Switch
            color={has(errors, "recurring") ? "error": "primary"}
            checked={get(formData, 'recurring', false) || false}
            onChange={onChange({formData, setFormData, key: 'recurring', isCheckbox: true})}/>
        }
        title="If preceding events should be auto generated."
        label="Recuring"
        />
      {has(errors, "recurring") && <FormHelperText error={true}>
        {get(errors, "recurring", []).join(" ")}
      </FormHelperText>}
    </FormControl>

    <FormControl fullWidth sx={{m: 2}}>
      <Button onClick={save(formData)}>Save</Button>
    </FormControl>
  </Box>
}
