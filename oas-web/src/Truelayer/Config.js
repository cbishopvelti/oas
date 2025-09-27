import { gql, useQuery, useMutation} from '@apollo/client'
import { Table, TableContainer, Box, Button,
  TableHead, TableRow, Stack,
  TableCell, TextField, Alert,
  TableBody, IconButton, FormControl,
  Switch, FormControlLabel, InputLabel,
  MenuItem, Select
} from '@mui/material';
import { parseErrors } from '../utils/util';
import { useState, useEffect } from "react";
import { has, get } from 'lodash';

export const ConfigTruelayer = () => {

  const [globalFormData, setGlobalFormData] = useState({})

  const tmp_errors = [];
  const errors = parseErrors(tmp_errors);

  const { data } = useQuery(gql`query {
    truelayer_config {
      client_id,
      client_secret
    }
  }`);

  useEffect(() => {
    setGlobalFormData(get(data, 'truelayer_config', {}))
  }, [data])

  const onChange = () => {

  }

  // console.log("001 the url", window.location.origin)

  return <div>
    <Box sx={{m: 2, display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="client_id"
            value={get(globalFormData, "client_id", '')}
            type="text"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "client_id"})}
            error={has(errors, "client_id")}
            helperText={get(errors, 'client_id', []). join(" ")}
          />
      </FormControl>
      <FormControl fullWidth sx={{mb: 2}}>
        <TextField
            label="client_secret"
            value={get(globalFormData, "client_secret", '')}
            type="text"
            onChange={onChange({formData: globalFormData, setFormData: setGlobalFormData, key: "client_secret"})}
            error={has(errors, "client_secret")}
            helperText={get(errors, 'client_secret', []). join(" ")}
          />
      </FormControl>
      <FormControl fullWidth>
        <Button href={`https://auth.truelayer.com/?response_type=code&client_id=oas1-9c7b5d&scope=info%20accounts%20balance%20cards%20transactions%20direct_debits%20standing_orders%20offline_access&redirect_uri=${window.location.origin}/truelayer/callback&providers=uk-ob-all%20uk-oauth-all`}>
            Authorize with Truelayer
        </Button>
      </FormControl>
    </Box>
  </div>
}
