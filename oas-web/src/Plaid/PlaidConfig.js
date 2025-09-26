import { gql, useQuery, useMutation } from '@apollo/client';
import { usePlaidLink } from 'react-plaid-link';
import { useState, useEffect } from 'react';
import { Table, TableContainer, Box, Button,
  TableHead, TableRow, Stack,
  TableCell, TextField, Alert,
  TableBody, IconButton, FormControl,
  Switch, FormControlLabel, InputLabel,
  MenuItem, Select
} from '@mui/material';


const PlaidRequisition2 = ({
  link_token
}) => {
  const [saveMutation, {error}] = useMutation(gql`mutation ($public_token: String!) {
    plaid_exchange_public_token(public_token: $public_token) {
      success
    }
  }`)

  const config = {
    onSuccess: (public_token, metadata) => {
      saveMutation({
        variables: {
          public_token: public_token,
          account_id: metadata.id,
          account_name: metadata.name
        }
      })
    },
    token: link_token
  };

  const {open, exit, ready} = usePlaidLink(config);

  // console.log("002 WAT", plaidLink);
  return <div>
    {ready && <button onClick={() => { open() }}>Plaid Link</button>}
  </div>
}

export const PlaidRequisition = () => {
  const [linkToken, setLinkToken] = useState();
  const {data} = useQuery(gql`
    query {
      plaid_link_token
    }
  `)

  useEffect(() => {
    if (!data) {
      return;
    }
    setLinkToken(data.plaid_link_token);
  }, [data])

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
    </Box>
    {linkToken && <PlaidRequisition2 link_token={linkToken} />}
  </div>
}
