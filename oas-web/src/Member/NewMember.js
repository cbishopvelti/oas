import { useEffect, useState } from "react";
import {
  Box,
  TextField,
  FormControl,
  Button,
  Stack,
  Alert,
  Switch,
  FormControlLabel
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
        email,
        is_member,
        is_admin,
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
      setFormData({is_member: true})
    }
  }, [id])
  useEffect(() => {
    if (get(data, 'member')) {
      setFormData({
        ...get(data, 'member')
      })
    }
  }, [data])

  const onChange = ({formData, setFormData, isCheckbox, key}) => (event) => {
    if (isCheckbox) {
      setFormData({
        ...formData,
        [key]: event.target.checked
      })
      return;
    }
    const value = event.target.value
    setFormData({
      ...formData,
      [key]: !value ? undefined : value
    })
  }

  const [mutate, {error}] = useMutation(gql`mutation (
    $id: Int, $name: String!, $email: String!,
    $is_member: Boolean, $is_admin: Boolean
  ){
    new_member (
      id: $id, name: $name, email: $email,
      is_member: $is_member, is_admin: $is_admin
    ) {
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
      <FormControl fullWidth sx={{m:2}}>
        <FormControlLabel
            control={
              <Switch 
                checked={get(formData, 'is_member', false) || false}
                onChange={onChange({formData, setFormData, key: 'is_member', isCheckbox: true})}/>
            }
            label="Is member" />
        <FormControlLabel
            control={
              <Switch 
                checked={get(formData, 'is_admin', false) || false}
                onChange={onChange({formData, setFormData, key: 'is_admin', isCheckbox: true})}/>
            }
            label="Is admin" />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
    </Box>
  )
}