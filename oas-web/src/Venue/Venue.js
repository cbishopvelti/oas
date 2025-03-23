import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button,
  Stack, Alert, Autocomplete, Tabs, Tab } from "@mui/material";
import TabContext from '@mui/lab/TabContext';
import TabList from '@mui/lab/TabList';
import TabPanel from '@mui/lab/TabPanel';
import { TimePicker } from "@mui/x-date-pickers/TimePicker"
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
    credit_amount: "",
    time: ""
  }
  const [formData, setFormData] = useReactState(defaultData);
  if (id) {
    id = parseInt(id)
  }
  const [attendance, setAttendance] = useReactState(0);

  const onChange = ({formData, setFormData, key}) => (event) => {
    if ((key === "cutoff_booking" || key === "cutoff_queue")) {
      if ( /^\d{0,3}:?\d{0,2}$/.test(event.target.value)) {
        setFormData({
          ...formData,
          [key]: event.target.value
        })
      } else {
        setFormData({
          ...formData,
          [key]: ""
        })
      }
    } else if (key === "time") {
      setFormData({
        ...formData,
        [key]: event
      })
    } else {
      setFormData({
        ...formData,
        [key]: !event.target.value ? undefined : event.target.value
      })
    }
  }

  const {data, refetch} = useQuery(gql`
    query($id: Int!) {
      training_where(id: $id) {
        id,
        name,
        credit_amount,
        time,
        cutoff_booking
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
      console.log("005", get(data, "training_where.time", ""))

      setFormData({
        ...get(data, "training_where", {}),
        credit_amount: get(data, "training_where.credit_amount", "") || "",
        time: moment(get(data, "training_where.time", ""), 'HH:mm:ss') || ""
      });
    }
  }, [data])

  const [mutate, {error}] = useMutation(gql`
    mutation(
      $id: Int,
      $name: String!,
      $credit_amount: String!,
      $time: String,
      $cutoff_booking: String,
    ) {
      training_where(
        id: $id,
        name: $name,
        credit_amount: $credit_amount,
        time: $time,
        cutoff_booking: $cutoff_booking
      ) {
        id
      }
    }
  `, {
    onError: () => { }
  })

  const save = (formData) => async () => {
    const variables = {
      ...formData,
      ...(formData.time ? { time: formData.time.format("HH:mm:ss") } : {})
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

  console.log("006", get(formData, "time", null))

  return <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
    <FormControl fullWidth sx={{mt: 2, mb: 2, m: 2}}>
      <TextField
        required
        id="name"
        label="Name (put non-public metadata after a #, eg `Oxsrad # Tuesdays`)"
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

    <FormControl fullWidth sx={{mt: 2, mb: 2, m: 2}}>
      <TimePicker
        label="Time"
        value={get(formData, "time", null)}
        onChange={
          onChange({ formData, setFormData, key: "time" })
        }
        ampm={false}
        renderInput={(params) => <TextField {...params}
          error={has(errors, "time")}
          helperText={get(errors, "time", []).join(" ")}
          />}
      />
    </FormControl>
    <FormControl fullWidth sx={{mt: 2, mb: 2, m: 2}}>
      <TextField
        label="Booking cutoff (HH:MM), how long before the event a prospective attendee can cancel."
        value={get(formData, "cutoff_booking", "") || ""}
        InputLabelProps={{
          shrink: true,
        }}
        onChange={
          onChange({ formData, setFormData, key: "cutoff_booking" })
        }
        placeholder="hh:mm"
        fullWidth
        />
    </FormControl>

    <FormControl fullWidth sx={{m: 2}}>
      <Button onClick={save(formData)}>Save</Button>
    </FormControl>
  </Box>
}
