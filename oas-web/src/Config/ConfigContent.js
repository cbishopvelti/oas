import { parseErrors } from "../utils/util"
import { get, has } from 'lodash'
import { useMutation, gql, useQuery } from "@apollo/client"
import { useState, useEffect } from "react"
import { Box, Stack, Alert, TextField,
  FormControl, Button
} from "@mui/material"

const onChange = ({formData, setFormData, key, isCheckbox}) => (event) => {
  if (isCheckbox) {
    setFormData({
      ...formData,
      [key]: event.target.checked
    })
    return;
  }
  const newFormData = ({
    ...formData,
    [key]: !event.target.value ? "" : event.target.value
  })

  console.log("001", newFormData)
  setFormData(newFormData)
}

export const ConfigContent = () => {

  const [data, setData] = useState({})

  const { data: gqlData, refetch } = useQuery(gql`
    query {
      config_config{
        content
        bacs
      }
    }
  `)

  useEffect(() => {
    setData(get(gqlData, "config_config", {}))
  }, [gqlData])

  const [saveConfig, {error}] = useMutation(gql`
    mutation($content: String!, $bacs: String!) {
      save_config_content(content: $content, bacs: $bacs) {
        success
      }
    }
  `)

  const errors = parseErrors(get(error, 'graphQLErrors', []))

  const save = async () => {
    console.log("002", data)
    try {
      await saveConfig({
        variables: {
          ...data
        }
      })

      refetch();
    } catch (err) {
      console.error(err)
    }
  }

  return <div>
    <Box sx={{m: 2, display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Bacs details"
            value={get(data, "bacs", '') || ''}
            type="text"
            multiline
            minRows={3}
            onChange={onChange({formData: data, setFormData: setData, key: "bacs"})}
            error={has(errors, "bacs")}
            helperText={get(errors, 'bacs', []). join(" ")}
            />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Home page content"
            value={get(data, "content", '') || ''}
            type="text"
            multiline
            minRows={3}
            onChange={onChange({formData: data, setFormData: setData, key: "content"})}
            error={has(errors, "content")}
            helperText={get(errors, 'content', []). join(" ")}
            />
      </FormControl>
      <FormControl fullWidth>
        <Button onClick={save}>Save</Button>
      </FormControl>
    </Box>
  </div>
}
