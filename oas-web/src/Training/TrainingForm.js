import { useState, useEffect } from "react";

import { useQuery, useMutation, gql } from "@apollo/client";
import moment from "moment";
import { get, omit, has, assign } from 'lodash';
import { Box, Stack, Alert, FormControl,
  TextField, Button, FormControlLabel, Switch } from '@mui/material'
import { TrainingTags } from "./TrainingTags";
import { TrainingWhere } from "./TrainingWhere";
import {useNavigate} from 'react-router-dom'
import { parseErrors } from "../utils/util";
import { TrainingFormTime } from "./TrainingFormTime";

export const TrainingForm = ({id, data, config, refetch}) => {
  const navigate = useNavigate();

  const defaultData = {
    when: moment().format("YYYY-MM-DD"),
    training_tags: []
  }
  const [formData, setFormData] = useState(defaultData);

  const { data: trainingWhere } = useQuery(gql`
    query($id: Int!) {
      training_where(id: $id) {
        limit
      }
    }
  `, {
    variables: {
      id: formData.training_where?.id
    },
    skip: !formData.training_where?.id
  })

  const {data: trainingWhereTime} = useQuery(gql`
    query($training_where_id: Int!, $when: String!) {
      training_where_time_by_date(when: $when, training_where_id: $training_where_id){
        limit
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
    setFormData((fd) => ({
      ...fd,
      limit: data?.training?.limit ||
        trainingWhereTime?.training_where_time_by_date?.limit ||
        trainingWhere?.training_where?.limit ||
        null
    }))
  }, [trainingWhereTime, trainingWhere])

  useEffect(() => {
    if (!id) {
      setFormData({
        ...defaultData,
      })
    }
  }, [id])


  useEffect(() => {
    if (!data) {
      return;
    }
    setFormData(
      {
        ...get(data, "training"),
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
    mutation ($when: String!, $training_tags: [TrainingTagArg]!, $training_where: TrainingWhereArg!, $notes: String, $commitment: Boolean,
      $start_time: String, $booking_offset: String, $end_time: String, $limit: Int,
      $exempt_membership_count: Boolean,
      $disable_warning_emails: Boolean
    ) {
      insert_training (when: $when, training_tags: $training_tags, training_where: $training_where, notes: $notes, commitment: $commitment,
        start_time: $start_time, booking_offset: $booking_offset, end_time: $end_time, limit: $limit,
        exempt_membership_count: $exempt_membership_count,
        disable_warning_emails: $disable_warning_emails
      ) {
        id
      }
    }
  `);
  const [updateMutation, {error: error2}] = useMutation(gql`
    mutation ($id: Int!, $when: String!, $training_tags: [TrainingTagArg]!, $training_where: TrainingWhereArg!, $notes: String, $commitment: Boolean,
      $start_time: String, $booking_offset: String, $end_time: String, $limit: Int,
      $exempt_membership_count: Boolean, $disable_warning_emails: Boolean
    ){
      update_training (
        when: $when,
        id: $id,
        training_tags: $training_tags,
        training_where: $training_where,
        notes: $notes,
        commitment: $commitment,
        start_time: $start_time,
        booking_offset: $booking_offset,
        end_time: $end_time,
        limit: $limit,
        exempt_membership_count: $exempt_membership_count,
        disable_warning_emails: $disable_warning_emails
      ) {
        id
      }
    }
  `)

  const save = (formData) => async () => {
    if (!formData.id) {
      try {
        const { data } = await insertMutation({
          variables: {
            ...omit(formData, ["training_tags.__typename", "training_where.__typename"]),
            notes: formData.notes || "",
            limit: formData.limit ? parseInt(formData.limit) : null
          }
        });

        navigate(`/training/${get(data, "insert_training.id")}`)
      }catch (err) {
        console.error(err)
      }
    } else if (formData.id) {
      try {
        const { data } = await updateMutation({
          variables: {
            ...omit(formData, ["training_tags.__typename", "training_where.__typename"]),
            notes: formData.notes || "",
            limit: formData.limit ? parseInt(formData.limit) : null
          }
        });

        setFormData({
          ...formData,
          saveCount: get(formData, "saveCount", 0) + 1
        })
      } catch (err) {
        console.error(err)
      }
    }

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

      {get(config, "config_config.enable_booking") && <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <FormControlLabel
          control={
            <Switch
              checked={get(formData, 'commitment', false) || false}
              onChange={(event) => {
                let tmpFormData = formData;
                if (event.target.checked === true) {
                  assign(tmpFormData, {
                    booking_offset: "",
                  })
                }
                onChange({ formData: tmpFormData, setFormData, key: 'commitment', isCheckbox: true })(event)
              }} />
          }
          label="Commitment mode"
          title="The user only gets a minute to cancel their booking, this will override any time settings."
        />
      </FormControl>}

      {!get(formData, 'commitment', false) && <TrainingFormTime formData={formData} setFormData={setFormData} errors={errors} />}

      <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <TextField
          id="limit"
          label="Limit"
          value={get(formData, "limit", '') || ''}
          onChange={
            onChange({formData, setFormData, key: "limit"})
          }
          InputLabelProps={{
            shrink: true
          }}
          error={has(errors, "limit")}
          helperText={get(errors, "limit", []).join(" ")}
          />
      </FormControl>

      <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <FormControlLabel
          control={
            <Switch
              checked={get(formData, 'exempt_membership_count', false) || false}
              onChange={(event) => {
                onChange({formData, setFormData, key: 'exempt_membership_count', isCheckbox: true})(event)
              }}
              />
          }
          label="Exempt from membership count"
          title="This training will not count towards a users trainings before they must become a full members"
          />
      </FormControl>

    <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
      <FormControlLabel
        control={
          <Switch
            checked={get(formData, 'disable_warning_emails', false) || false}
            onChange={(event) => {
              onChange({formData, setFormData, key: 'disable_warning_emails', isCheckbox: true})(event)
            }}
          />
        }
        label="Disable warning emails"
        title="This will stop any emails that attending this event might trigger."
        />
    </FormControl>

      <FormControl fullWidth sx={{mt: 2, mb: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
  </Box>
}
