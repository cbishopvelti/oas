import { useEffect, useRef, useState } from 'react'
import {
  Box,
  FormControl,
  FormControlLabel,
  Button,
  Stack,
  Alert,
  InputLabel,
  Input,
  Table,
  TableContainer,
  TableHead,
  TableBody,
  TableRow,
  TableCell
} from '@mui/material'
import { useMutation, gql, useQuery} from '@apollo/client'
import { TransactionsImportEditor } from './TransactionsImportEditor';
import { get } from 'lodash';
import { useOutletContext } from 'react-router-dom'


export const TransactionsImport = () => {
  const { setTitle } = useOutletContext();
  const [formData, setFormData ] = useState({});
  const fileRef = useRef(null);

  const {data, refetch} = useQuery(gql`
    query {
      transactions_import {
        account,
        date,
        bank_account_name,
        member {
          id,
          name
        },
        state,
        my_reference,
        amount,
        errors {
          transaction_id,
          name
        },
        warnings
      }
    }
  `)

  useEffect(() => {
    setTitle("Import Transactions");
    refetch();
  }, [])

  const errors = {};

  function onChange(event) {
    setFormData({
      ...formData,
      file: event.target.files[0]
    })
  }

  const [mutate] = useMutation(gql`
    mutation ($file: Upload!) {
      import_transactions (file: $file) {
        success
      }
    }
  `);

  const importData = (formData) => async () => {
    const { file } = formData
    await mutate({
      variables: {
        file: file
      }
    });

    fileRef.current.value = "";

    refetch()
  }

  const [resetMutation] = useMutation(gql`
    mutation {
      reset_import_transactions {
        success
      }
    }
  `)

  const reset = () => {
    if (fileRef && fileRef.current) {
      fileRef.current.value = "";
    }
    resetMutation();
    refetch()
  }

  return <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
    {!data?.transactions_import && <>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>

      <FormControl fullWidth sx={{m:2}}>
        <InputLabel
          shrink
          htmlFor="importInput">
          Statement csv
        </InputLabel>
          <br/>
        <Input
          required
          id="importInput"
          type="file"
          accept=".csv"
          ref={fileRef}
          onChange={onChange}
        />
      </FormControl>

      <FormControl fullWidth sx={{m:2}}>
        <Button onClick={importData(formData)}>Import</Button>
      </FormControl>
    </>}

    {data?.transactions_import && <TransactionsImportEditor transactions_import={data.transactions_import} refetch={refetch} />}

    <FormControl fullWidth sx={{m: 2}}>
      <Button onClick={reset} variant="outlined" color="error">Reset</Button>
    </FormControl>
  </Box>
}
