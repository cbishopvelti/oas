import { useState } from 'react';
import { Button, Box, FormControl, TextField,
  Table,
  TableContainer,
  TableCell,
  TableHead, 
  TableRow,
  TableBody,
  Stack,
  Alert
} from '@mui/material';
import { get, setWith, clone, has, chain } from 'lodash';
import { useQuery, useLazyQuery, gql} from '@apollo/client';
import moment from 'moment';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom'


const onChange = ({formData, setFormData, key}) => (event) => {
  let value = event.target.value
  
  formData = setWith(clone(formData), key, value, clone)
  setFormData(formData)
}

const isUsable = (member_email) => (token) => {
  if (moment(token.expires_on).isBefore(moment())) {
    return false;
  }
  if(token.used_on) {
    return false
  }
  if (token.member.email != member_email) {
    // given to someone else
    return false;
  }

  return true;
}

export const Tokens = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  
  const member_email = searchParams.get('email');

  const [formData, setFormData] = useState({
    email: member_email
  })
  const navigate = useNavigate()

  const { data, error } = useQuery(gql`
    query($email: String!) {
      public_tokens(email: $email) {
        id,
        value,
        expires_on,
        used_on,
        member {
          email,
          name
        },
        tr_member {
          email,
          name
        }
      }
    }
  `, {
    variables: {
      email: member_email
    },
    skip: !member_email
  })
  const tokens = get(data, 'public_tokens', []);
  const errors = get(error, 'graphQLErrors')

  const tokenCount = chain(get(data, 'public_tokens'))
    .filter(isUsable(member_email))
    .value()
    .length

  
  const onClick = () => {
    setSearchParams(formData)
  }

  return <Box>
    <Box sx={{display: 'flex', alignItems: 'center'}}>
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
    </Box>
    <Box>
    <Stack sx={{ width: '100%', mt: 2 }}>
      {errors?.map(({message}, i) => (
        <Alert key={i} severity="error">{message}</Alert>
      ))}
    </Stack>
    {has(data, 'public_tokens') && <>
      <p>You have <b>{tokenCount}</b> token{tokenCount == 1 ? '' : 's'}</p>
      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Id</TableCell>
              <TableCell>Owner</TableCell>
              <TableCell>Creater</TableCell>
              <TableCell>Expires on</TableCell>
              <TableCell>Used on</TableCell>
              <TableCell>Value</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {
              tokens.map((token) => {
                const sx = {
                  ...(!isUsable(member_email)(token) ? {
                    color: "gray",
                    textDecoration: "line-through"
                  }: {}),
                }

                return (<TableRow key={token.id}>
                  <TableCell sx={sx}>{token.id}</TableCell>
                  <TableCell sx={sx}>{token.member.name}</TableCell>
                  <TableCell sx={sx}>{token.tr_member?.name}</TableCell>
                  <TableCell sx={sx}>{token.expires_on}</TableCell>
                  <TableCell sx={sx}>{token.used_on}</TableCell>
                  <TableCell sx={sx}>{token.value}</TableCell>
                </TableRow>)
              })
            }
          </TableBody>
        </Table>
      </TableContainer>
    </>}
    </Box>

  </ Box>
}