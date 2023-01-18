import { useEffect, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { useQuery, gql, useMutation } from "@apollo/client"
import { Table, TableContainer, Box, Button,
  TableHead, TableRow, Stack,
  TableCell, TextField, Alert,
  TableBody, IconButton, FormControl,
  Switch, FormControlLabel
} from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import { get, has } from 'lodash'
import SaveIcon from '@mui/icons-material/Save';
import { parseErrors } from "../utils/util";

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

export const ConfigTokens = () => {
  const { setTitle } = useOutletContext();
  const [formData, setFormData] = useState({})
  const [globalFormData, setGlobalFormData] = useState({})

  useEffect(() => {
    setTitle("Config")
  }, []);

  const { data, refetch } = useQuery(gql`
    query {
      config_tokens {
        id,
        value,
        quantity
      },
      config_config {
        token_expiry_days,
        temporary_trainings,
        bacs,
        enable_booking,
        name
      }
    }
  `);
  const config_tokens = get(data, 'config_tokens', []) || [];
  const config_config = get(data, 'config_config', []) || []

  useEffect(() => {
    setGlobalFormData(config_config)
  }, [data])

  const [saveMutation, {error}] = useMutation(gql`
    mutation ($quantity: Int!, $value: String!) {
      save_config_token(quantity: $quantity, value: $value) {
        id
      }
    }
  `)

  const [saveGlobalMutation, {error: error2}] = useMutation(gql`
    mutation(
      $token_expiry_days: Int,
      $temporary_trainings: Int,
      $bacs: String,
      $enable_booking: Boolean,
      $name: String
    ) {
      save_config_config(
        token_expiry_days: $token_expiry_days,
        temporary_trainings: $temporary_trainings,
        bacs: $bacs, 
        enable_booking: $enable_booking,
        name: $name
      ) {
        id
      }
    }
  `)

  const [deleteMutation] = useMutation(gql`
    mutation($id: Int!) {
      delete_config_token(id: $id) {
        success
      }
    }
  `)

  const deleteClick = (id) => async () => {
    await deleteMutation({
      variables: {
        id: id
      }
    })
    refetch();
  }

  const save = (formData) => async () => {
    await saveMutation({
      variables: {
        ...formData,
        quantity: parseInt(formData.quantity)
      }
    })

    setFormData({})

    refetch();
  }



  const saveGlobal = async () => {
    await saveGlobalMutation({
      variables: {
        ...globalFormData,
        token_expiry_days: parseInt(globalFormData.token_expiry_days),
        temporary_trainings: parseInt(globalFormData.temporary_trainings)
      }
    })
  }

  const errors = parseErrors([
    ...get(error, 'graphQLErrors', []),
    ...get(error2, 'graphQLErrors', [])
  ]);

  return <div>
    <Box sx={{m: 2, display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Society name (for emails)"
            value={get(globalFormData, "name", '')}
            type="text"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "name"})}
            error={has(errors, "name")}
            helperText={get(errors, 'name', []). join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Trainings someone is allowed to attend before they need full membership"
            value={get(globalFormData, "temporary_trainings", '')}
            type="number"
            pattern='[0-9]*'
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "temporary_trainings"})}
            error={has(errors, "temporary_trainings")}
            helperText={get(errors, 'temporary_trainings', []). join(" ")}
            />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Bacs details"
            value={get(globalFormData, "bacs", '')}
            type="text"
            multiline
            minRows={3}
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "bacs"})}
            error={has(errors, "bacs")}
            helperText={get(errors, 'bacs', []). join(" ")}
            />
      </FormControl>

      <FormControl fullWidth sx={{mb: 2}}>
        <FormControlLabel
          control={
            <Switch 
              checked={get(globalFormData, 'enable_booking', false) || false}
              onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: 'enable_booking', isCheckbox: true})}/>
          }
          label="Enable booking functionality" />
      </FormControl>

      <FormControl fullWidth sx={{mb:2}}>
        <TextField
            label="Token Expiry Days"
            value={get(globalFormData, "token_expiry_days", '')}
            type="number"
            pattern='[0-9]*'
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "token_expiry_days"})}
            error={has(errors, "token_expiry_days")}
            helperText={get(errors, 'token_expiry_days', []). join(" ")}
            />
      </FormControl>
      <FormControl fullWidth>
        <Button onClick={saveGlobal}>Save</Button>
      </FormControl>
      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Id</TableCell>
              <TableCell>Quantity</TableCell>
              <TableCell>Value</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {config_tokens.map((configToken) => {
              
              return <TableRow key={configToken.id}>
                <TableCell>{configToken.id}</TableCell>
                <TableCell>{configToken.quantity}</TableCell>
                <TableCell>{configToken.value}</TableCell>
                <TableCell>
                  <IconButton onClick={deleteClick(configToken.id)}>
                    <DeleteIcon sx={{color: 'red'}}/>
                  </IconButton>
                </TableCell>
              </TableRow>
            })}
            <TableRow>
              <TableCell></TableCell>
              <TableCell>
                <TextField
                  required
                  id="quantity"
                  label="Quantity"
                  inputProps={{ inputMode: 'numeric', pattern: '[0-9]*' }}
                  value={get(formData, 'quantity', '')}
                  onChange={
                    onChange({formData, setFormData, key: "quantity"})
                  }
                  error={has(errors, "quantity")}
                  helperText={get(errors, "quantity", []).join(" ")}
                ></TextField>
              </TableCell>
              <TableCell>
                <TextField 
                  required
                  id="value"
                  label="Value"
                  value={get(formData, 'value', '')}
                  onChange={
                    onChange({formData, setFormData, key: 'value'})
                  }
                  error={has(errors, "value")}
                  helperText={get(errors, 'value', []). join(" ")}
                ></TextField>
              </TableCell>
              <TableCell>
                <IconButton onClick={save(formData)}>
                  <SaveIcon />                 
                </IconButton>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  </div>
}