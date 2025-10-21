import { useEffect, useState } from 'react';
import {useOutletContext, Link } from 'react-router-dom';
import { useQuery, gql, useMutation } from "@apollo/client"
import { Table, TableContainer, Box, Button,
  TableHead, TableRow, Stack,
  TableCell, TextField, Alert,
  TableBody, IconButton, FormControl,
  Switch, FormControlLabel, InputLabel,
  MenuItem, Select,
  InputAdornment, OutlinedInput
} from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import Visibility from '@mui/icons-material/Visibility';
import VisibilityOff from '@mui/icons-material/VisibilityOff';
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

  const newFormData = ({
    ...formData,
    [key]: !event.target.value ? "" : event.target.value
  })

  setFormData(newFormData)
}

export const ConfigTokens = () => {
  const { setTitle } = useOutletContext();
  const [formData, setFormData] = useState({})
  const [globalFormData, setGlobalFormData] = useState({})
  const [showGocardlessKey, setShowGocardlessKey] = useState(false);

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
        content,
        enable_booking,
        name,
        gocardless_id,
        gocardless_key,
        gocardless_account_id,
        credits,
        backup_recipient
      },
      gocardless_accounts {
        id
      }
    }
  `);
  const config_tokens = get(data, 'config_tokens', []) || [];
  const config_config = get(data, 'config_config', []) || [];
  const gocardless_accounts = get(data, 'gocardless_accounts', []) || []

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
      $content: String,
      $enable_booking: Boolean,
      $name: String
      $gocardless_id: String
      $gocardless_key: String
      $gocardless_account_id: String
      $credits: Boolean
      $backup_recipient: String
    ) {
      save_config_config(
        token_expiry_days: $token_expiry_days,
        temporary_trainings: $temporary_trainings,
        bacs: $bacs,
        content: $content,
        enable_booking: $enable_booking,
        name: $name,
        gocardless_id: $gocardless_id,
        gocardless_key: $gocardless_key,
        gocardless_account_id: $gocardless_account_id
        credits: $credits
        backup_recipient: $backup_recipient
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
    try {
      await saveGlobalMutation({
        variables: {
          ...globalFormData,
          token_expiry_days: parseInt(globalFormData.token_expiry_days),
          temporary_trainings: parseInt(globalFormData.temporary_trainings)
        }
      })
    } catch (error) {
      console.error(error);
    }
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
            value={get(globalFormData, "name", '') || ""}
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
            value={get(globalFormData, "bacs", '') || ''}
            type="text"
            multiline
            minRows={3}
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "bacs"})}
            error={has(errors, "bacs")}
            helperText={get(errors, 'bacs', []). join(" ")}
            />
      </FormControl>

      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Content"
            value={get(globalFormData, "content", '') || ''}
            type="text"
            multiline
            minRows={3}
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "content"})}
            error={has(errors, "content")}
            helperText={get(errors, 'content', []). join(" ")}
            />
      </FormControl>

      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Go cardless id"
            value={get(globalFormData, "gocardless_id", '') || ''}
            type="text"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "gocardless_id"})}
            error={has(errors, "gocardless_id")}
            helperText={get(errors, 'gocardless_id', []). join(" ")}
            />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <InputLabel htmlFor="gocardless-key">Gocardless key</InputLabel>
        <OutlinedInput
            id="gocardless-key"
            label="Go cardless key"
            value={get(globalFormData, "gocardless_key", '') || ''}
            type={showGocardlessKey ? "text" : "password"}
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "gocardless_key"})}
            error={has(errors, "gocardless_key")}
            helperText={get(errors, 'gocardless_key', []). join(" ")}
            endAdornment={
              <InputAdornment position="end">
                <IconButton
                  aria-label={
                    showGocardlessKey ? 'hide the password' : 'display the password'
                  }
                  onClick={() => {
                    setShowGocardlessKey(!showGocardlessKey)
                  }}
                  edge="end"
                >
                  {showGocardlessKey ? <VisibilityOff /> : <Visibility />}
                </IconButton>
              </InputAdornment>
            }
            />
      </FormControl>

      <FormControl fullWidth sx={{mb: 2}}>
        <Link to={'/config/gocardless'}>Gocardless requisition flow</Link>
      </FormControl>

      {gocardless_accounts &&
        // gocardless_accounts.find(({id}) => id == globalFormData.gocardless_account_id) &&
        gocardless_accounts.length > 0 &&
      <FormControl fullWidth sx={{ mb: 2 }}>
        <InputLabel required id="account">Account</InputLabel>
        <Select
          labelId="account"
          label="Account"
          onChange={onChange({ formData: globalFormData, setFormData: setGlobalFormData, key: "gocardless_account_id" })}
          value={globalFormData.gocardless_account_id || ""}>
          {gocardless_accounts && gocardless_accounts.map((dat, id) => {
            return <MenuItem key={`account-${id}`} value={dat.id}>{dat.id}</MenuItem>
          })}
        </Select>
      </FormControl>}

      <FormControl fullWidth sx={{mb: 2}}>
        <FormControlLabel
          control={
            <Switch
              checked={get(globalFormData, 'enable_booking', false) || false}
              onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: 'enable_booking', isCheckbox: true})}/>
          }
          label="Enable booking functionality" />
      </FormControl>

      <FormControl fullWidth sx={{mb: 2}}>
        <FormControlLabel
          control={
            <Switch
              checked={get(globalFormData, 'credits', false) || false}
              onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: 'credits', isCheckbox: true})}/>
          }
          label="Enable credits functionality" />
      </FormControl>

      <FormControl fullWidth sx={{mb:2}}>
        <TextField
            label="Credit/Token Expiry Days"
            value={get(globalFormData, "token_expiry_days", '')}
            type="number"
            pattern='[0-9]*'
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "token_expiry_days"})}
            error={has(errors, "token_expiry_days")}
            helperText={get(errors, 'token_expiry_days', []). join(" ")}
            />
      </FormControl>

      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Backup recipient"
            value={get(globalFormData, "backup_recipient", '') || ""}
            type="email"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "backup_recipient"})}
            error={has(errors, "backup_recipient")}
            helperText={get(errors, 'backup_recipient', []). join(" ")}
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
