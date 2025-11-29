import { useState, useEffect } from "react";

import { useQuery, useMutation, gql } from "@apollo/client";
import moment from "moment";
import { get, omit, has } from 'lodash';
import { Box, Stack, Alert, FormControl,
  TextField, Button, FormControlLabel, Switch } from '@mui/material'
import { TrainingTags } from "./TrainingTags";
import { TrainingWhere } from "./TrainingWhere";
import {useNavigate} from 'react-router-dom'
import { parseErrors } from "../utils/util";



export const TrainingForm = ({id, data, refetch}) => {
  const navigate = useNavigate();


  // const {data} = useQuery(gql`
  //   query($id: Int!) {
  //     training(id: $id) {
  //       id,
  //       when,
  //       notes,
  //       training_where {
  //         id,
  //         name
  //       }
  //       training_tags {
  //         id,
  //         name
  //       }
  //     }
  //   }
  // `, {
  //   variables: {
  //     id: id
  //   },
  //   skip: !id
  // })

  const defaultData = {
    when: moment().format("YYYY-MM-DD"),
    training_tags: []
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
    setFormData(
      {
        ...get(data, "training")
      }
    )
  }, [data])

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
  const [ insertMutation, {error: error1} ] = useMutation(gql`
    mutation ($when: String!, $training_tags: [TrainingTagArg]!, $training_where: TrainingWhereArg!, $notes: String, $commitment: Boolean) {
      insert_training (when: $when, training_tags: $training_tags, training_where: $training_where, notes: $notes, commitment: $commitment) {
        id
      }
    }
  `);
  const [updateMutation, {error: error2}] = useMutation(gql`
    mutation ($id: Int!, $when: String!, $training_tags: [TrainingTagArg]!, $training_where: TrainingWhereArg!, $notes: String, $commitment: Boolean){
      update_training (
        when: $when,
        id: $id,
        training_tags: $training_tags,
        training_where: $training_where,
        notes: $notes
        commitment: $commitment
      ) {
        id
      }
    }
  `)

  const save = (formData) => async () => {
    if (!formData.id) {
      const { data } = await insertMutation({
        variables: {
          ...omit(formData, ["training_tags.__typename", "training_where.__typename"]),
          notes: formData.notes || ""
        }
      });

      navigate(`/training/${get(data, "insert_training.id")}`)
    } else if (formData.id) {
      const { data } = await updateMutation({
        variables: {
          ...omit(formData, ["training_tags.__typename", "training_where.__typename"]),
          notes: formData.notes || ""
        }
      });
    }
    setFormData({
      ...formData,
      saveCount: get(formData, "saveCount", 0) + 1
    })
    refetch()
  }

  const errors = parseErrors([
    ...get(error1, "graphQLErrors", []),
    ...get(error2, "graphQLErrors", [])
  ]);

  return <Box sx={{width: '100%'}}>
    <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{mb: 2}}>
        <TrainingWhere
          formData={formData}
          setFormData={setFormData}
          errors={errors}
          />
      </FormControl>
      {/* <FormControl fullWidth sx={{mt: 2, mb: 2}}>
        <TrainingTags
          formData={formData}
          setFormData={setFormData}
        />
      </FormControl> */}
      <FormControl fullWidth sx={{mt: 2, mb: 2}}>
        <TextField
          required
          id="when"
          label="When"
          value={get(formData, "when", '')}
          type="date"
          onChange={
            onChange({formData, setFormData, key: "when"})
          }
          InputLabelProps={{
            shrink: true,
          }}
          error={has(errors, "when")}
          helperText={get(errors, "when", []).join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mt: 2, mb: 2}}>
        <TextField
          id="notes"
          label="Notes"
          value={get(formData, "notes", '') || ''}
          type="text"
          multiline
          onChange={
            onChange({formData, setFormData, key: "notes"})
          }
          error={has(errors, "notes")}
          helperText={get(errors, "notes", []).join(" ")}
          />
      </FormControl>

      {get(data, "config_config.enable_booking") && <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <FormControlLabel
          control={
            <Switch
              checked={get(formData, 'commitment', false) || false}
              onChange={onChange({ formData, setFormData, key: 'commitment', isCheckbox: true })} />
          }
          label="Commitment mode"
          title="The user only gets a minute to cancel their booking, this will override any time settings."
        />
      </FormControl>}

      <FormControl fullWidth sx={{mt: 2, mb: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
  </Box>
}
