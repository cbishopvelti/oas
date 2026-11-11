import { useEffect, useState } from 'react';
import {useOutletContext, Link } from 'react-router-dom';
import { useQuery, gql, useMutation } from "@apollo/client"
import { Table, TableContainer, Box, Button,
  TableHead, TableRow, Stack,
  TableCell, TextField, Alert,
  TableBody, IconButton, FormControl,
  Switch, FormControlLabel, InputLabel,
  MenuItem, Select,
  InputAdornment, OutlinedInput,
  Autocomplete, FormHelperText
} from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import { get, has } from 'lodash'
import SaveIcon from '@mui/icons-material/Save';
import { parseErrors } from "../utils/util";

const supportedValues = (key, fallback) => {
  try {
    return Intl.supportedValuesOf(key)
  } catch (e) {
    return fallback
  }
}

const TIME_ZONES = supportedValues('timeZone', ['Europe/London', 'UTC'])
const CURRENCIES = supportedValues('currency', ['GBP', 'EUR', 'USD'])

// Keeps the saved value selectable even if this browser's list lacks it.
const withValue = (options, value) =>
  value && !options.includes(value) ? [value, ...options] : options

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
        credits,
        backup_recipient,
        short_name,
        contact_email,
        time_zone,
        currency,
        phone_country_code,
        logo_url,
        primary_color,
        public_site_title
      }
    }
  `);
  const config_tokens = get(data, 'config_tokens', []) || [];
  const config_config = get(data, 'config_config', []) || [];

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
      $enable_booking: Boolean,
      $name: String
      $credits: Boolean
      $backup_recipient: String
      $short_name: String
      $contact_email: String
      $time_zone: String
      $currency: String
      $phone_country_code: String
      $logo_url: String
      $primary_color: String
      $public_site_title: String
    ) {
      save_config_config(
        token_expiry_days: $token_expiry_days,
        temporary_trainings: $temporary_trainings,
        enable_booking: $enable_booking,
        name: $name,
        credits: $credits
        backup_recipient: $backup_recipient
        short_name: $short_name
        contact_email: $contact_email
        time_zone: $time_zone
        currency: $currency
        phone_country_code: $phone_country_code
        logo_url: $logo_url
        primary_color: $primary_color
        public_site_title: $public_site_title
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
      refetch();
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
            label="Short name (e.g. OAS)"
            value={get(globalFormData, "short_name", '') || ""}
            type="text"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "short_name"})}
            error={has(errors, "short_name")}
            helperText={get(errors, 'short_name', []).join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Public site title"
            value={get(globalFormData, "public_site_title", '') || ""}
            type="text"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "public_site_title"})}
            error={has(errors, "public_site_title")}
            helperText={get(errors, 'public_site_title', []).join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Contact email"
            value={get(globalFormData, "contact_email", '') || ""}
            type="email"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "contact_email"})}
            error={has(errors, "contact_email")}
            helperText={get(errors, 'contact_email', []).join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <Autocomplete
          options={withValue(TIME_ZONES, globalFormData.time_zone)}
          value={get(globalFormData, "time_zone", null) || null}
          onChange={(event, value) => setGlobalFormData({...globalFormData, time_zone: value || ""})}
          renderInput={(params) => <TextField
            {...params}
            label="Time zone"
            error={has(errors, "time_zone")}
            helperText={get(errors, 'time_zone', []).join(" ")}
          />}
        />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}} error={has(errors, "currency")}>
        <InputLabel id="config-currency-label">Currency</InputLabel>
        <Select
          labelId="config-currency-label"
          label="Currency"
          value={get(globalFormData, "currency", '') || ''}
          onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "currency"})}
        >
          {withValue(CURRENCIES, globalFormData.currency).map((code) => (
            <MenuItem key={code} value={code}>{code}</MenuItem>
          ))}
        </Select>
        <FormHelperText>{get(errors, 'currency', []).join(" ")}</FormHelperText>
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Phone country code (digits, no +)"
            value={get(globalFormData, "phone_country_code", '') || ""}
            type="text"
            inputProps={{ inputMode: 'numeric', pattern: '[0-9]*' }}
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "phone_country_code"})}
            error={has(errors, "phone_country_code")}
            helperText={get(errors, 'phone_country_code', []).join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Logo URL"
            value={get(globalFormData, "logo_url", '') || ""}
            type="url"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "logo_url"})}
            error={has(errors, "logo_url")}
            helperText={get(errors, 'logo_url', []).join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Primary colour (e.g. #1a2b3c)"
            value={get(globalFormData, "primary_color", '') || ""}
            type="text"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "primary_color"})}
            error={has(errors, "primary_color")}
            helperText={get(errors, 'primary_color', []).join(" ")}
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
