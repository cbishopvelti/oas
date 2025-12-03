import { parseErrors } from "../utils/util"
import {
  Box, Button, InputLabel, Stack,
  TextField, Alert, OutlinedInput,
  FormControl, InputAdornment, IconButton,
  Switch, FormControlLabel, Select, MenuItem
} from '@mui/material';
import {useQuery, gql, useMutation} from '@apollo/client'
import { get, has } from 'lodash'
import {useEffect, useState} from 'react'
import Visibility from '@mui/icons-material/Visibility';
import VisibilityOff from '@mui/icons-material/VisibilityOff';
import {useOutletContext, Link } from 'react-router-dom';

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

export const ConfigGocardless = () => {

  const { setTitle } = useOutletContext();
  const [formData, setFormData] = useState({})
  const [showGocardlessKey, setShowGocardlessKey] = useState(false)

  useEffect(() => {
    setTitle("Gocardless config")
  }, [])

  const { data: gqlData, refetch } = useQuery(gql`
    query {
      config_config{
        gocardless_enabled
        gocardless_id
        gocardless_key
        gocardless_account_id
      }
      gocardless_accounts {
        id
      }
    }
  `)
  const gocardless_accounts = get(gqlData, 'gocardless_accounts', []) || []

  useEffect(() => {
    setFormData(get(gqlData, "config_config", {}))
  }, [gqlData])

  const [saveConfig, {error}] = useMutation(gql`
    mutation(
      $gocardless_enabled: Boolean!
      $gocardless_id: String,
      $gocardless_key: String,
      $gocardless_account_id: String
    ) {
      save_config_gocardless(
        gocardless_enabled: $gocardless_enabled,
        gocardless_id: $gocardless_id,
        gocardless_key: $gocardless_key,
        gocardless_account_id: $gocardless_account_id
      ) {
        id
      }
    }
  `)

  const errors = parseErrors(get(error, 'graphQLErrors', []))

  const save = async () => {
    try {
      await saveConfig({
        variables: {
          ...formData
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
        <FormControlLabel
          control={
            <Switch
              checked={get(formData, 'gocardless_enabled', false) || false}
              onChange={onChange({formData: formData, setFormData: setFormData, key: 'gocardless_enabled', isCheckbox: true})}/>
          }
          label="Gocardless Enabled" />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="Go cardless id"
            value={get(formData, "gocardless_id", '') || ''}
            type="text"
            onChange={onChange({formData: formData, setFormData: setFormData, key: "gocardless_id"})}
            error={has(errors, "gocardless_id")}
            helperText={get(errors, 'gocardless_id', []). join(" ")}
            />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <InputLabel htmlFor="gocardless-key">Gocardless key</InputLabel>
        <OutlinedInput
            id="gocardless-key"
            label="Go cardless key"
            value={get(formData, "gocardless_key", '') || ''}
            type="text"
            sx={showGocardlessKey ? {} : {textSecurity: "disc", "WebkitTextSecurity":"disc"}}

            autoComplete="off"
            onChange={onChange({formData: formData, setFormData: setFormData, key: "gocardless_key"})}
            error={has(errors, "gocardless_key")}
            helpertext={get(errors, 'gocardless_key', []). join(" ")}
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
        <Button
          to={'/config/gocardless'}
          component={Link}
          color="success"
          sx={{width: '100%'}}
          disabled={!get(formData, "gocardless_id") || !get(formData, "gocardless_key") ||
            get(formData, "gocardless_key") !== get(gqlData, "config_config.gocardless_key") ||
            get(formData, "gocardless_id") !== get(gqlData, "config_config.gocardless_id")}
          >
            Gocardless requisition flow
          </Button>
      </FormControl>

      {gocardless_accounts &&
        // gocardless_accounts.find(({id}) => id == globalFormData.gocardless_account_id) &&
        gocardless_accounts.length > 0 &&
      <FormControl fullWidth sx={{ mb: 2 }}>
        <InputLabel required id="account">Account</InputLabel>
        <Select
          labelId="account"
          label="Account"
          onChange={onChange({ formData: formData, setFormData: setFormData, key: "gocardless_account_id" })}
          value={formData.gocardless_account_id || ""}>
          {gocardless_accounts && gocardless_accounts.map((dat, id) => {
            return <MenuItem key={`account-${id}`} value={dat.id}>{dat.id}</MenuItem>
          })}
        </Select>
      </FormControl>}
      <FormControl fullWidth>
        <Button onClick={save}>Save</Button>
      </FormControl>
    </Box>
  </div>
}
