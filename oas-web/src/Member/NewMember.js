import { useEffect, useState } from "react";
import {
  Box,
  TextField,
  FormControl,
  Button,
  Stack,
  Alert
} from "@mui/material"
import { get } from "lodash";
import { useMutation, gql, useQuery } from "@apollo/client";
import { useParams, useNavigate } from 'react-router-dom';

export const NewMember = () => {
  const navigate = useNavigate();

  let { id } = useParams();
  if ( id ) {
    id = parseInt(id);
  }
  const [formData, setFormData] = useState({});

  const {data, refetch} = useQuery(gql`
    query ($id: Int!){
      member (member_id: $id) {
        id,
        name,
        email
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
      setFormData({})
    }
  }, [id])
  useEffect(() => {
    if (get(data, 'member')) {
      setFormData({
        ...get(data, 'member')
      })
    }
  }, [data])

  const onChange = ({formData, setFormData, key}) => (event) => {
    setFormData({
      ...formData,
      [key]: !event.target.value ? undefined : event.target.value
    })
  }

  const [mutate, {error}] = useMutation(gql`mutation ($id: Int, $name: String!, $email: String!){
    new_member (id: $id, name: $name, email: $email) {
      id
    }
  }`)
  const save = (formData) => async () => {
    const { data } = await mutate({
      variables: formData
    })

    navigate(`/member/${get(data, 'new_member.id')}`);
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
          id="email"
          label="Email"
          value={get(formData, "email", '')}
          onChange={onChange({formData, setFormData, key: "email"})}
        />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="name"
          label="Name"
          value={get(formData, "name", '')}
          onChange={onChange({formData, setFormData, key: 'name'})}
        />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
    </Box>
  )
}