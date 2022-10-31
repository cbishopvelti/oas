import { useEffect, useState } from 'react'
import {
  Box,
  FormControl,
  TextField,
  Button,
  Stack,
  Alert
} from '@mui/material'
import { get } from 'lodash'
import * as moment from 'moment'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, gql, useMutation, from } from '@apollo/client';


const onChange = ({formData, setFormData, key}) => (event) => {
  
  let name
  if (key == "from" || key == "to") {
    let dates = {
      from: formData.from,
      to: formData.to,
      [key]: !event.target.value ? undefined : event.target.value
    }
    name = `${moment(dates.from).format("YYYY")}-${moment(dates.to).format("yyyy")}`
  }

  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value,
    ...(name ? {name} : {})
  })
}

export const MembershipPeriod = () => {

  const navigate = useNavigate();
  let { id } = useParams()
  if (id) {
    id = parseInt(id);
  }

  const defaultData = {};
  const [formData, setFormData] = useState(defaultData);

  const {data, refetch} = useQuery(gql`
    query($id: Int!) {
      membership_period(id: $id) {
        id,
        to,
        from,
        name,
        value
      }
    }
  `, {
    variables: {
      id
    },
    skip: !id
  })
  useEffect(() => {
    refetch()
    if (!id) {
      setFormData(defaultData)
    }
  }, [id])
  useEffect(() => {
    if (get(data, 'membership_period')) {
      setFormData({
        ...get(data, 'membership_period')
      })
    }
  }, [data])

  const [mutate, { error }] = useMutation(gql`
    mutation ($id: Int, $to: String!, $from: String!, $name: String!, $value: String!) {
      membership_period(id: $id, to: $to, from: $from, name: $name, value: $value) {
        id
      }
    }
  `);
  const save = () => async () => {
    const { data } = await mutate({
      variables: {
        ...formData
      }
    })

    navigate(`/membership-period/${get(data, 'membership_period.id')}`);
  }

  return (
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {get(error, "graphQLErrors", []).map(({message}, i) => (
            <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
            required
            id="from"
            label="From"
            value={get(formData, "from", '')}
            type="date"
            onChange={
              onChange({formData, setFormData, key: "from"})
            }
            InputLabelProps={{
              shrink: true,
            }}
             />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
          <TextField
            required
            id="to"
            label="To"
            value={get(formData, "to", '')}
            type="date"
            onChange={
              onChange({formData, setFormData, key: "to"})
            }
            InputLabelProps={{
              shrink: true,
            }}
            />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="name"
          label="Name"
          value={get(formData, "name", '')}
          onChange={onChange({formData, setFormData, key: "name"})}
          />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="value"
          label="Value"
          value={get(formData, "value", '')}
          type="number"
          onChange={onChange({formData, setFormData, key: "value"})}
          />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
    </Box>
  )
}