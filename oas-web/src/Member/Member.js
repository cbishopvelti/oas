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
import { get, omit, has } from "lodash";
import { useMutation, gql, useQuery } from "@apollo/client";
import { useParams, useNavigate, useOutletContext } from 'react-router-dom';
import { parseErrors } from '../utils/util';
import { MemberDetails } from "./MemberDetails";

export const Member = () => {
  const { setTitle } = useOutletContext();
  const navigate = useNavigate();
  const [editMemberDetails, setEditMemberDetails] = useState(false)

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
        bank_account_name,
        is_active,
        is_admin,
        is_reviewer
        member_details {
          phone,
          address,
          dob,
          nok_name,
          nok_email,
          nok_phone,
          nok_address,
          agreed_to_tac
        }
      }
    }
  `, {
    variables: {
      id
    },
    skip: !id
  })

  useEffect(() => {
    setTitle("Member");
    refetch()
    if (!id) {
      setFormData({is_active: true})
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
        [key]: event.target.checked,
        ...(key == "is_admin" && event.target.checked ? {is_reviewer: false, is_active: true} : {}),
        ...(key == "is_reviewer" && event.target.checked ? {is_admin: false, is_active: true} : {}),
        ...(key === "is_active" && !event.target.checked ? {is_admin: false, is_reviewer: false} : {})
      })
      return;
    }
    const value = event.target.value
    setFormData({
      ...formData,
      [key]: !value ? undefined : value
    })
  }

  const [mutate, {error, data: mutationData}] = useMutation(gql`mutation (
    $id: Int, $name: String!, $email: String!,
    $is_active: Boolean,
    $is_admin: Boolean,
    $is_reviewer: Boolean,
    $member_details: MemberDetailsArg,
    $bank_account_name: String
  ){
    member (
      id: $id, name: $name, email: $email,
      is_reviewer: $is_reviewer,
      is_active: $is_active,
      is_admin: $is_admin,
      member_details: $member_details,
      bank_account_name: $bank_account_name
    ) {
      id,
      password
    }
  }`)
  const errors = parseErrors(error?.graphQLErrors)

  const save = (formData) => async () => {
    const { data } = await mutate({
      variables: omit(formData, 'member_details.__typename')
    })

    navigate(`/member/${get(data, 'member.id')}`);
  }

  if (get(mutationData, 'member.password')) {
    console.info(
      "This members password is: ",
      get(mutationData, 'member.password')
    );
  }

  return (
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
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
          error={has(errors, "email")}
          helperText={get(errors, "email", []).join(" ")}
        />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="name"
          label="Name"
          value={get(formData, "name", '')}
          onChange={onChange({formData, setFormData, key: 'name'})}
          error={has(errors, "name")}
          helperText={get(errors, "name", []).join(" ")}
        />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          id="bank_account_name"
          label="Bank Account Name"
          value={get(formData, "bank_account_name", '') || ''}
          onChange={onChange({formData, setFormData, key: 'bank_account_name'})}
          error={has(errors, "bank_account_name")}
          helperText={get(errors, "bank_account_name", []).join(" ")}
        />
      </FormControl>
      <FormControl fullWidth sx={{m:2}}>
        <FormControlLabel
            control={
              <Switch 
                checked={get(formData, 'is_active', false) || false}
                onChange={onChange({formData, setFormData, key: 'is_active', isCheckbox: true})}/>
            }
            label="Is active" />
        <FormControlLabel
            control={
              <Switch 
                checked={get(formData, 'is_reviewer', false) || false}
                onChange={onChange({formData, setFormData, key: 'is_reviewer', isCheckbox: true})}/>
            }
            label="Is reviewer" />
        <FormControlLabel
            control={
              <Switch 
                checked={get(formData, 'is_admin', false) || false}
                onChange={onChange({formData, setFormData, key: 'is_admin', isCheckbox: true})}/>
            }
            label="Is admin" />
      </FormControl>

      <FormControl fullWidth sx={{m:2}}>
        <FormControlLabel
          control={
            <Switch 
              checked={editMemberDetails}
              onChange={(event) => setEditMemberDetails(event.target.checked)}/>
          }
          label="Edit Member Details" />
      </FormControl>

      
      {editMemberDetails && <MemberDetails
        errors={errors}
        setFormData={setFormData}
        formData={formData} />}

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
    </Box>
  )
}