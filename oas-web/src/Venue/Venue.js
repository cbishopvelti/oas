import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button,
  Stack, Alert, Autocomplete, Tabs, Tab } from "@mui/material";
import TabContext from '@mui/lab/TabContext';
import TabList from '@mui/lab/TabList';
import TabPanel from '@mui/lab/TabPanel';
import { useEffect, useState as useReactState } from "react";
// import { useState } from "../utils/useState";
import moment from "moment";
import { get, omit, has } from 'lodash'
import { useNavigate, useParams, useOutletContext } from "react-router-dom";
import { parseErrors } from "../utils/util";

export const Venue = () => {
  const { setTitle } = useOutletContext();
  const navigate = useNavigate();
  let params = useParams()
  let id = params?.id
  const defaultData = {
    name: "",
    credit_amount: ""
  }
  const [formData, setFormData] = useReactState(defaultData);
  if (id) {
    id = parseInt(id)
  }
  const [attendance, setAttendance] = useReactState(0);

  const onChange = ({formData, setFormData, key}) => (event) => {
    setFormData({
      ...formData,
      [key]: !event.target.value ? undefined : event.target.value
    })
  }

  const {data, refetch} = useQuery(gql`
    query($id: Int!) {
      training_where(id: $id) {
        id,
        name,
        credit_amount
      }
    }
  `, {
    variables: {
      id: id
    },
    skip: !id
  })

  useEffect(() => {
    if (!id) {
      setTitle("New Venue");
    } else {
      setTitle(`Editing Venue: ${get(data, 'training_were.name', id)}`)
    }
    refetch()
    if (!id) {
      setFormData(defaultData)
    }
  }, [id])
  useEffect(() => {
    if (get(data, "training_where")) {
      setFormData({
        ...get(data, "training_where", {}),
        credit_amount: get(data, "training_where.credit_amount", "") || ""
      });
    }
  }, [data])

  const [mutate, {error}] = useMutation(gql`
    mutation($id: Int, $name: String!, $credit_amount: String!) {
      training_where(id: $id, name: $name, credit_amount: $credit_amount) {
        id
      }
    }
  `, {
    onError: () => { }
  })

  const save = (formData) => async () => {
    const variables = {
      ...formData
    }

    const { data, errors } = await mutate({
      variables
    });

    setFormData({
      ...formData,
      saveCount: get(formData, "saveCount", 0) + 1
    })

    // return; // DEBUG ONLY, remove

    if (get(data, 'training_where.id')) {
      refetch()
      navigate(`/venue/${get(data, 'training_where.id')}`)
    }
  }

  const errors = parseErrors(error?.graphQLErrors);

  return <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
    <FormControl fullWidth sx={{mt: 2, mb: 2, m: 2}}>
      <TextField
        required
        id="name"
        label="Name"
        value={get(formData, "name", '')}
        onChange={
          onChange({formData, setFormData, key: "name"})
        }
        InputLabelProps={{
          shrink: true,
        }}
        error={has(errors, "name")}
        helperText={get(errors, "name", []).join(" ")}
        />
    </FormControl>

    <FormControl fullWidth sx={{mt: 2, mb: 2, m: 2}}>
      <TextField
        required
        id="credit-amount"
        label="Amount"
        value={get(formData, "credit_amount", '')}
        onChange={
          onChange({formData, setFormData, key: "credit_amount"})
        }
        InputLabelProps={{
          shrink: true,
        }}
        inputMode="numeric"
        pattern="[0-9\.]*"
        error={has(errors, "credit_amount")}
        helperText={get(errors, "credit_amount", []).join(" ")}
        />
    </FormControl>
    <FormControl fullWidth sx={{m: 2}}>
      <Button onClick={save(formData)}>Save</Button>
    </FormControl>
  </Box>
}
