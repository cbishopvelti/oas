import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button, Stack, Alert, Autocomplete } from "@mui/material";
import { useEffect, useState } from "react";
import moment from "moment";
import { get, omit, has } from 'lodash'
import { useNavigate, useParams } from "react-router-dom";
import { TrainingAttendance } from "./TrainingAttendance";
import { TrainingTags } from "./TrainingTags";
import { TrainingWhere } from "./TrainingWhere";
import { parseErrors } from "../utils/util";


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
        training_where {
          id,
          name
        }
        training_tags {
          id,
          name
        }
      }
    }
  `, {
    variables: {
      id: id
    },
    skip: !id
  })

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

  const onChange = ({formData, setFormData, key, direct}) => (event) => {
    setFormData({
      ...formData,
      [key]: !event.target.value ? undefined : event.target.value
    })
  }


  const [ insertMutation, {error: error1} ] = useMutation(gql`
    mutation ($when: String!, $training_tags: [TrainingTagArg]!, $training_where: TrainingWhereArg!){
      insert_training (when: $when, training_tags: $training_tags, training_where: $training_where) {
        id
      }
    }
  `);
  const [updateMutation, {error: error2}] = useMutation(gql`
    mutation ($id: Int!, $when: String!, $training_tags: [TrainingTagArg]!, $training_where: TrainingWhereArg!){
      update_training (
        when: $when,
        id: $id,
        training_tags: $training_tags,
        training_where: $training_where
      ) {
        id
      }
    }
  `)

  const save = (formData) => async () => {
    if (!formData.id) {
      const { data } = await insertMutation({
        variables: {
          ...omit(formData, ["training_tags.__typename", "training_where.__typename"])
        }
      });

      navigate(`/training/${get(data, "insert_training.id")}`)
    } else if (formData.id) {
      const { data } = await updateMutation({
        variables: {
          ...omit(formData, ["training_tags.__typename", "training_where.__typename"])
        }
      });
    }
    setFormData({
      ...formData,
      saveCount: get(formData, "saveCount", 0) + 1
    })
  }

  const errors = parseErrors([
    ...get(error1, "graphQLErrors", []),
    ...get(error2, "graphQLErrors", [])
  ]);

  return <div>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{m: 2}}>
        <TrainingWhere
          formData={formData}
          setFormData={setFormData}
          errors={errors}
          />
      </FormControl>
      {/* <FormControl fullWidth sx={{m: 2}}>
        <TrainingTags 
          formData={formData}
          setFormData={setFormData}
        />
      </FormControl> */}
      <FormControl fullWidth sx={{m: 2}}>
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
          error={has(errors, "training_where")}
          helperText={get(errors, "training_where", []).join(" ")}
          />
      </FormControl>
      

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
    </Box>
    {id && <TrainingAttendance trainingId={id} />}
  </div>
}
