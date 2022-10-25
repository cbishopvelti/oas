import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button, Stack, Alert, Autocomplete } from "@mui/material";
import { useEffect, useState } from "react";
import moment from "moment";
import { get } from 'lodash'
import { useNavigate, useParams } from "react-router-dom";
import { TrainingAttendance } from "./TrainingAttendance";


export const Training = () => {
  const navigate = useNavigate();
  let { id } = useParams()
  if (id) {
    id = parseInt(id)
  }

  const {data} = useQuery(gql`
    query($id: Int!) {
      training(id: $id) {
        id,
        when,
        where
      }
    }
  `, {
    variables: {
      id: id
    },
    skip: !id
  })

  const defaultData = {
    when: moment().format("YYYY-MM-DD")
  }
  const [formData, setFormData] = useState(defaultData);

  useEffect(() => {
    if (!id) {
      setFormData(defaultData)
    }
  }, [id])

  useEffect(() => {
    if (!data) {
      return;
    }
    setFormData(get(data, "training"))
  }, [data])

  const onChange = ({formData, setFormData, key, direct}) => (event) => {
    setFormData({
      ...formData,
      [key]: !event.target.value ? undefined : event.target.value
    })
  }


  const [ insertMutation, {error: error1} ] = useMutation(gql`
    mutation ($where: String!, $when: String!){
      insert_training (where: $where, when: $when) {
        id
      }
    }
  `);
  const [updateMutation, {error: error2}] = useMutation(gql`
    mutation ($id: Int!, $where: String!, $when: String!){
      update_training (where: $where, when: $when, id: $id) {
        id
      }
    }
  `)

  const save = (formData) => async () => {
    if (!formData.id) {
      const { data } = await insertMutation({
        variables: formData
      });

      navigate(`/training/${get(data, "insert_training.id")}`)
    } else if (formData.id) {
      console.log('007', formData)
      const { data } = await updateMutation({
        variables: formData
      });
    }
  }

  return <div>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {[...get(error1, "graphQLErrors", []), ...get(error2, "graphQLErrors", [])].map(({message}, i) => (
            <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="where"
          label="where"
          value={get(formData, "where", '')}
          onChange={onChange({formData, setFormData, key: "where"})}
        />
      </FormControl>
      <FormControl>
        <Autocomplete
          id="trainingTags"
          value={get(formData, "training_tags") || ''}
          options={(/* trainingTags */[]).map(({name, id}) => ({label: name, id: id }))}
          renderInput={(params) => <TextField {...params} required label="Tag" />}
          onChange={(event, newValue, a, b, c, d) => {
            console.log('training_tags', newValue)
          }}
        />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="when"
          label="When"
          value={get(formData, "when", '')}
          type="date"
          onChange={
            onChange({formData, setFormData, key: "when"})
          } />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
    </Box>
    {id && <TrainingAttendance trainingId={id} />}
  </div>
}
