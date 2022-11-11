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
  Stack,
  Alert
} from '@mui/material'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { get, find, omit, has } from 'lodash'
import * as moment from 'moment'
import { useParams, useNavigate, useOutletContext } from 'react-router-dom'
import { useQuery, gql, useMutation } from '@apollo/client';
import { TransactionNewToken } from "./TransactionToken";
import { Tokens } from './Tokens';
import { TransactionTags } from './TransactionTags';
import { TransactionMembershipPeriod } from './TransactionMembershipPeriod';
import { parseErrors } from '../utils/util';

export const Transaction = () => {
  const { setTitle } = useOutletContext();
  
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
        their_reference,
        my_reference,
        transaction_tags {
          id,
          name
        },
        tokens {
          id
        },
        membership {
          membership_period_id
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
    setTitle("Transaction");
    refetch()
    if (!id) {
      setFormData(defaultData)
    }
  }, [id])
  useEffect(() => {
    if (get(data, "transaction")) {
      
      setFormData({
        ...get(data, "transaction", {}),
        ...(has(data, "transaction.membership.membership_period_id") ? { membership_period_id: get(data, "transaction.membership.membership_period_id")} : {})
      });
    }
  }, [data])
  useEffect(() => {
    if (formData.type === "INCOMING") {
      setFormData({
        ...omit(formData, 'their_reference'),
      })
    }
  }, [formData.type])
  

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
    $token_value: Float,
    $transaction_tags: [TransactionTagArg],
    $membership_period_id: Int,
    $their_reference: String
    $my_reference: String!
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
      transaction_tags: $transaction_tags,
      membership_period_id: $membership_period_id,
      their_reference: $their_reference,
      my_reference: $my_reference
    ) {
      id
    }
  }`)
  const errors = parseErrors(error?.graphQLErrors);
  const save = (formData) => async () => {
    formData = omit(formData, "training_tags.__typename");

    const { data } = await mutate({
      variables: {
        ...formData,
        amount: parseFloat(get(formData, 'amount')),
        ...(get(formData, 'who_member_id') ? {who_member_id: parseInt(get(formData, 'who_member_id'))} : {}),
        ...(formData.token_quantity ? {token_quantity: parseInt(formData.token_quantity)}: {}),
        transaction_tags: (formData.transaction_tags.map((item) => omit(item, '__typename') ))
      }
    });

    setFormData({
      ...formData,
      saveCount: get(formData, "saveCount", 0) + 1
    })

    // return; // DEBUG ONLY, remove

    refetch()
    navigate(`/transaction/${get(data, 'transaction.id')}`)
  }

  return <>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
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
          error={has(errors, "what")}
          helperText={get(errors, "what", []).join(' ')}
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
          }
          InputLabelProps={{
            shrink: true,
          }}
          error={has(errors, "when")}
          helperText={get(errors, "when", []).join(' ')}
          />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <Autocomplete
            id="member"
            freeSolo
            required
            value={formData.who || find(members, ({id}) => id === formData.who_member_id)?.name || ''}
            options={members.map(({name, id}) => ({label: name, who_member_id: id }))}
            renderInput={(params) => <TextField
              {...params}
              label="Who"
              required
              error={has(errors, "who") || has(errors, "who_member_id")}
              helperText={[...get(errors, "who", []), get(errors, "who_member_id", [])].join(' ')}
              />
            }
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
          error={has(errors, "type")}
        >
          <MenuItem value={'INCOMING'}>Incoming</MenuItem>
          <MenuItem value={'OUTGOING'}>Outgoing</MenuItem>
        </Select>
      </FormControl>

      <FormControl fullWidth sx={{m:2, display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', gap: 2, flexDirection: 'row'}}>
        {(get(formData, 'type') == 'OUTGOING') && <TextField
          sx={{flexGrow: 1}}
          label="Their Reference"
          value={get(formData, "their_reference", '') || ''}
          onChange={onChange({formData, setFormData, key: 'their_reference'})}
          error={has(errors, "their_reference")}
          helperText={get(errors, "their_reference", []).join(' ')}
          />}

        <TextField
          sx={{flexGrow: 1}}
          label={`${((get(formData, 'type') === 'OUTGOING') ? 'My' : 'Received')} Reference`}
          value={get(formData, "my_reference", '') || ''}
          required
          onChange={onChange({formData, setFormData, key: "my_reference"})}
          error={has(errors, "my_reference")}
          helperText={get(errors, "my_reference", []).join(' ')}
          />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <TextField 
          label="Amount"
          value={get(formData, "amount", '')}
          type="number"
          required
          onChange={onChange({formData, setFormData, key: "amount"})}
          error={has(errors, "amount")}
          helperText={get(errors, "amount", []).join(' ')}
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
          error={has(errors, "bank_details")}
          helperText={get(errors, "bank_details", []).join(' ')}
          />

      </FormControl>

      <FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Notes"
          value={get(formData, "notes", '') || ''}
          multiline
          onChange={onChange({formData, setFormData, key: "notes"})}
          error={has(errors, "notes")}
          helperText={get(errors, "notes", []).join(' ')}
          />
      </FormControl>

      <TransactionNewToken 
        formData={formData}
        setFormData={setFormData}
        id={id} />

      <TransactionMembershipPeriod
        formData={formData}
        setFormData={setFormData}
        id={id}
      />

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>

    </Box>
    {get(data, "transaction") && <Tokens transaction={get(data, "transaction")} />}
  </>
}