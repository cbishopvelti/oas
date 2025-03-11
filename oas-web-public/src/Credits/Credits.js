import { useState } from 'react';
import { Button, Box, FormControl, TextField,
  Table,
  TableContainer,
  TableCell,
  TableHead,
  TableRow,
  TableBody,
  Stack,
  Alert,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Typography
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import { get, setWith, clone, has, chain, uniqBy } from 'lodash';
import { useQuery, useLazyQuery, gql} from '@apollo/client';
import moment from 'moment';
import { useParams, useNavigate, useSearchParams, useOutletContext } from 'react-router-dom'

const onChange = ({formData, setFormData, key}) => (event) => {
  let value = event.target.value

  formData = setWith(clone(formData), key, value, clone)
  setFormData(formData)
}

export const Credits = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [outletContext] = useOutletContext();

  const member_email = get(outletContext, 'user.email') || searchParams.get('email') || '';

  const [formData, setFormData] = useState({
    email: member_email
  })
  const navigate = useNavigate()

  const { data, error } = useQuery(gql`
    query($email: String!) {
      public_credits(email: $email) {
        id,
        what,
        expires_on,
        when,
        amount,
        after_amount
      }
      public_bacs(email: $email)
    }
    `, {
    variables: {
      email: member_email
    },
    skip: !member_email
  })

  const credits = get(data, 'public_credits', []);
  console.log("001 credits", credits);
  const errors = uniqBy(get(error, 'graphQLErrors', []), "message")

  const onClick = () => {
    setSearchParams(formData)
  }

  const currentBalance = credits.length > 0 ?
     credits[0].after_amount :
     0;

  return <Box>
    {!get(outletContext, 'user.email') && <Box sx={{display: 'flex', alignItems: 'center'}}>
      <FormControl sx={{flexGrow: 5}}>
        <TextField
          required
          id="email"
          label="Email"
          value={get(formData, "email", '')}
          onChange={onChange({formData, setFormData, key: "email"})}
          error={has(errors, "email")}
          helperText={get(errors, "email", []).join(" ")}
        />
      </FormControl>
      <FormControl>
        <Button onClick={onClick}>Find</Button>
      </FormControl>
    </Box>}

    <Box>
      {errors.length !== 0 && <Stack sx={{ width: '100%', mt: 2 }}>
        {errors.map(({message}, i) => (
          <Alert key={i} severity="error">{message}</Alert>
        ))}
      </Stack>}

      {errors.length == 0 && has(data, 'public_credits') &&
        <h3 style={{ ...currentBalance< 0? { color: "red" } : { }}}>Your current credit balance is <b>{currentBalance}</b>.</h3>}

      {errors.length == 0 && has(data, 'public_credits') &&
        <p>Credits are used to pay for training sessions and other activities.</p>}

      {!errors.length && has(data, 'public_bacs') && <Accordion sx={{position: 'relative'}}>
        <AccordionSummary
          expandIcon={<ExpandMoreIcon />}
          aria-controls="panel1a-content"
          id="panel1a-header"
        >
          <Typography>Add more credits</Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Typography>
            Please make a bacs transfer to:<br/>
            <br/>
            {get(data, 'public_bacs', []).map((item, i) => <span key={i}>{item}<br/></ span>)}
            <br/>
            Credits will be added to your account after your payment is processed. Please include your name and email in the payment reference.
          </Typography>
        </AccordionDetails>
      </Accordion>}


      {has(data, 'public_credits') && credits.length > 0 && <>
        <h3>Credit Transactions</h3>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Id</TableCell>
                <TableCell>Transaction</TableCell>
                <TableCell>When</TableCell>
                <TableCell>Expires On</TableCell>
                <TableCell>Amount</TableCell>
                <TableCell>Balance After</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {
                credits.map((credit) => {
                  const isExpired = credit.expires_on && moment(credit.expires_on).isBefore(moment());

                  const sx = {
                    ...(isExpired ? {
                      color: "gray",
                      textDecoration: "line-through"
                    } : {}),
                  }

                  return (<TableRow key={credit.id}>
                    <TableCell sx={sx}>{credit.id}</TableCell>
                    <TableCell sx={sx}>{credit.what}</TableCell>
                    <TableCell sx={sx}>{credit.when}</TableCell>
                    <TableCell sx={sx}>{credit.expires_on || 'N/A'}</TableCell>
                    <TableCell sx={sx}>{credit.amount}</TableCell>
                    <TableCell sx={sx}>{credit.after_amount}</TableCell>
                  </TableRow>)
                })
              }
            </TableBody>
          </Table>
        </TableContainer>
      </>}

      {has(data, 'public_credits') && credits.length === 0 &&
        <Alert severity="info" sx={{ mt: 2 }}>You don't have any credit transactions yet.</Alert>
      }
    </Box>
  </Box>
}
