import { useState } from "react";
import { useQuery, gql, useMutation } from "@apollo/client"
import { Table, TableContainer, Box, Button,
  TableHead, TableRow, Stack,
  TableCell, TextField, Alert,
  TableBody, IconButton, FormControl,
  Switch, FormControlLabel, Select, MenuItem,
  InputLabel,
  Link
} from '@mui/material';

export const Gocardless = () => {
  const [bank, setBank] = useState("");
  const [requisition, setRequisition] = useState("");

  const { data, refetch } = useQuery(gql`
    query {
      gocardless_banks {
        id,
        name
      }
    }
  `);

  const [mutation] = useMutation(gql`
    mutation($institution_id: String!) {
      gocardless_requisitions (institution_id: $institution_id) {
        id,
        link
      }
    }
  `)

  const doAuthentication = async () => {

    const { data } = await mutation({
      variables: {
        institution_id: bank
      }
    })

    setRequisition(data.gocardless_requisitions.link)
  }

  return <div>
    <Box sx={{m: 2, display: 'flex', flexWrap: 'wrap' }}>
      <FormControl fullWidth sx={{mb: 2}}>
        <InputLabel required id="bank-label">Bank</InputLabel>
        <Select
          labelId="bank-label"
          label="Bank"
          required
          onChange={(event) => {
            setBank(event.target.value)
          }}
          value={bank}>
          {data?.gocardless_banks && data.gocardless_banks.map((dat, id) => {
            return <MenuItem key={ `bank-${id}`} value={ dat.id }>{dat.name}</MenuItem>
          })}
          {<MenuItem key={'bank-gocardless'} value={'SANDBOXFINANCE_SFIN0000'}>SANDBOXFINANCE_SFIN0000</MenuItem>}
        </Select>

      </FormControl>
    </Box>
    {bank && <FormControl fullWidth>
      <Button onClick={ doAuthentication } >Generate Requisition Link</Button>
      </FormControl>
    }
    {requisition && <FormControl fullWidth style={{textAlign: 'center'}}>
      <Link href={requisition}>{requisition}</Link>
    </FormControl>}
  </div>
}
