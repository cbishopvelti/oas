import { parseErrors } from "../utils/util"
import { Table, TableContainer, Box, Button,
  TableHead, TableRow, Stack,
  TableCell, TextField, Alert,
  TableBody, IconButton, FormControl,
  Switch, FormControlLabel, InputLabel,
  MenuItem, Select,
  InputAdornment, OutlinedInput
} from '@mui/material';
import {useQuery, gql, useMutation} from '@apollo/client'
import { get, has } from 'lodash'
import {useEffect, useState} from 'react'

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

  setFormData(newFormData)
}

export const ConfigLlm = () => {

  const [data, setData] = useState({})

  const { data: gqlData, refetech } = useQuery(gql`
    query {
      config_llm {
        context
      }
    }
  `)

  useEffect(() => {
    setData(get(gqlData, "config_llm", {}))
  }, [gqlData])

  const [saveConfig, {error}] = useMutation(gql`
    mutation($context: String!) {
      save_config_llm(context: $context) {
        context
      }
    }
  `)

  const errors = parseErrors([])

  const save = async () => {
    try {
      await saveConfig({
        variables: {
          ...data
        }
      })
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
            label="Llm context"
            value={get(data, "context", '') || ""}
            minRows={3}
            multiline
            type="text"
            onChange={onChange({formData: data, setFormData: setData, key: "context"})}
            error={has(errors, "data")}
            helperText={get(errors, 'data', []). join(" ")}
          />
      </FormControl>
      <FormControl fullWidth>
        <Button onClick={save}>Save</Button>
      </FormControl>
    </Box>
  </div>
}
