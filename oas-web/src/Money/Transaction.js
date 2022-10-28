import { useEffect, useState } from 'react'
import {
  Box,
  FormControl,
  TextField,
  Autocomplete,
  Select,
  MenuItem,
  InputLabel,
  Button,
  FormControlLabel,
  Switch,
  Stack,
  Alert
} from '@mui/material'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { get, find, omit } from 'lodash'
import * as moment from 'moment'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, gql, useMutation } from '@apollo/client';
import { TransactionNewToken } from "./TransactionToken";
import { Tokens } from './Tokens';
import { TransactionTags } from './TransactionTags';



export const Transaction = () => {
  const navigate = useNavigate();
  let { id } = useParams()
  if (id) {
    id = parseInt(id);
  }

  const defaultData = {
    when: moment().format("YYYY-MM-DD")
  };

  const [formData, setFormData] = useState(defaultData);

  const {data, refetch} = useQuery(gql`
    query ($id: Int!) {
      transaction (id: $id) {
        id,
        what,
        when,
        who,
        who_member_id,
        type,
        amount,
        bank_details,
        notes,
        tokens {
          id
        },
        transaction_tags {
          id,
          name
        }
      }
    }
  `, {
    variables: {
      id
    },
    skip: !id
  })
  useEffect(() => {
    refetch()
    if (!id) {
      setFormData(defaultData)
    }
  }, [id])
  useEffect(() => {
    if (get(data, "transaction")) {
      setFormData(get(data, "transaction"));
    }
  }, [data])
  

  let { data: membersData, refetch: refetechMembers } = useQuery(gql`query {
    members {
      id,
      name
    }
  }`);
  const members = get(membersData, 'members', [])
  useEffect(() => {
    refetechMembers()
  }, [])

  const onChange = ({formData, setFormData, key}) => (event) => {
    
    setFormData({
      ...formData,
      [key]: !event.target.value ? undefined : event.target.value
    })
  }

  const filter = createFilterOptions();

  const [mutate, {error}] = useMutation(gql`mutation (
    $id: Int,
    $what: String!,
    $when: String!,
    $who: String,
    $who_member_id: Int,
    $type: String!,
    $amount: Float!,
    $bank_details: String,
    $notes: String,
    $token_quantity: Int,
    $token_value: Float
    $transaction_tags: [TransactionTagArg]
  ){
    transaction (
      id: $id,
      what: $what,
      when: $when,
      who: $who,
      who_member_id: $who_member_id,
      type: $type,
      amount: $amount,
      bank_details: $bank_details,
      notes: $notes,
      token_quantity: $token_quantity,
      token_value: $token_value,
      transaction_tags: $transaction_tags
    ) {
      id
    }
  }`)
  const save = (formData) => async () => {
    formData = omit(formData, "training_tags.__typename");
    const { data } = await mutate({
      variables: {
        ...formData,
        amount: parseFloat(get(formData, 'amount')),
        ...(get(formData, 'who_member_id') ? {who_member_id: parseInt(get(formData, 'who_member_id'))} : {}),
        ...(formData.token_quantity ? {token_quantity: parseInt(formData.token_quantity)}: {})
      }
    });

    setFormData({
      ...formData,
      saveCount: get(formData, "saveCount", 0) + 1
    })

    return; // DEBUG ONLY, remove

    refetch()
    navigate(`/transaction/${get(data, 'transaction.id')}`)
  }

  return <>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {get(error, "graphQLErrors", []).map(({message}, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="what"
          label="What"
          value={get(formData, "what", '')}
          onChange={onChange({formData, setFormData, key: "what"})}
        />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="when"
          label="When"
          value={get(formData, "when", '')}
          type="date"
          onChange={
            onChange({formData, setFormData, key: "when"})
          } />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <Autocomplete
            id="member"
            freeSolo
            required
            value={formData.who || find(members, ({id}) => id === formData.who_member_id)?.name || ''}
            options={members.map(({name, id}) => ({label: name, who_member_id: id }))}
            renderInput={(params) => <TextField {...params} label="Who" required />}
            filterOptions={(options, params) => {

              const filtered = filter(options, params);

              const { inputValue } = params;

              let add = []
              const isExisting = options.some((option) => inputValue === option.label);
              if (inputValue && !isExisting) {
                add = [{label: `Pay "${inputValue}"`, who: inputValue}]
              }

              return [...add, ...filtered];
            }}
            clearOnBlur
            selectOnFocus
            handleHomeEndKeys
            onChange={(event, newValue, a, b, c, d) => {
              if (newValue?.who) {
                setFormData({
                  ...formData,
                  who: newValue.who,
                  who_member_id: undefined
                })
              } else if (newValue?.who_member_id) {
                setFormData({
                  ...formData,
                  who: newValue.label,
                  who_member_id: newValue.who_member_id 
                })
              } else {
                setFormData({
                  ...formData,
                  who: undefined,
                  who_member_id: undefined
                })
              }
            }}
          />
      </FormControl>
      
      <FormControl fullWidth sx={{m: 2}}>
        <InputLabel required id="transaction-type">Type</InputLabel>

        <Select
          labelId="transaction-type"
          label="Type"
          required
          onChange={onChange({formData, setFormData, key: "type"})}
          value={get(formData, "type", '')}
        >
          <MenuItem value={'INCOMING'}>Incoming</MenuItem>
          <MenuItem value={'OUTGOING'}>Outgoing</MenuItem>
        </Select>
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <TextField 
          label="Amount"
          value={get(formData, "amount", '')}
          type="number"
          required
          onChange={onChange({formData, setFormData, key: "amount"})}
        />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <TransactionTags 
          formData={formData}
          setFormData={setFormData}
        />
      </FormControl>

      <FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Bank Details"
          value={get(formData, "bank_details", '') || ''}
          multiline
          onChange={onChange({formData, setFormData, key: "bank_details"})}
          />

      </FormControl>

      <FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Notes"
          value={get(formData, "notes", '') || ''}
          multiline
          onChange={onChange({formData, setFormData, key: "notes"})}
          />

      </FormControl>

      <TransactionNewToken 
        formData={formData}
        setFormData={setFormData}
        id={id} />

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>

    </Box>
    {get(data, "transaction") && <Tokens transaction={get(data, "transaction")} />}
  </>
}