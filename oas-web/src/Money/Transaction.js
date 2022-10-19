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
  Switch
} from '@mui/material'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { get, find, omit } from 'lodash'
import * as moment from 'moment'
import { Form } from 'react-router-dom'
import { useQuery, gql, useMutation } from '@apollo/client';



export const Transaction = () => {

  const [formData, setFormData] = useState({
    when: moment().format("YYYY-MM-DD")
  });

  let { data } = useQuery(gql`query {
    members {
      id,
      name
    }
  }`);
  const members = get(data, 'members', [])

  const onChange = ({formData, setFormData, key, direct}) => (event) => {
    
    setFormData({
      ...formData,
      [key]: direct ? event : event.target.value
    })
  }

  const filter = createFilterOptions();

  const [mutate] = useMutation(gql`mutation (
    $what: String!,
    $when: String!,
    $who: String,
    $who_member_id: Int,
    $type: String!,
    $amount: Float!,
    $bank_details: String,
    $notes: String,
    $token_quantity: Int
  ){
    transaction (
      what: $what,
      when: $when,
      who: $who,
      who_member_id: $who_member_id,
      type: $type,
      amount: $amount,
      bank_details: $bank_details,
      notes: $notes,
      token_quantity: $token_quantity
    ) {
      id
    }
  }`)
  const save = (formData) => () => {
    mutate({
      variables: {
        ...formData,
        amount: parseFloat(get(formData, 'amount')),
        ...(get(formData, 'who_member_id') ? {who_member_id: parseInt(get(formData, 'who_member_id'))} : {}),
        ...(formData.token_quantity ? {token_quantity: parseInt(formData.token_quantity)}: {})
      }
    })
  }

  const [buyingTokens, setBuyingTokens] = useState(false)
  const [canBuyTokens, setCanBuyTokens] = useState(false);
  useEffect(() => {
    setCanBuyTokens(
      formData.who_member_id && formData.type === "INCOMING"
    );
  }, [formData.who_member_id, formData.type])
  useEffect(() => {
    if (!canBuyTokens) {
      setBuyingTokens(false)
      setFormData(omit(formData, 'tokenQuantity'))
    }
  }, [canBuyTokens])
  useEffect(() => {
    if (!buyingTokens) {
      setFormData(omit(formData, 'tokenQuantity'))
    }
  }, [buyingTokens])


  return <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
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

    <FormControl fullWidth sx={{m:2}}>
      <TextField
        label="Bank Details"
        value={get(formData, "bank_details", '')}
        multiline
        onChange={onChange({formData, setFormData, key: "bank_details"})}
        />

    </FormControl>

    <FormControl fullWidth sx={{m:2}}>
      <TextField
        label="Notes"
        value={get(formData, "notes", '')}
        multiline
        onChange={onChange({formData, setFormData, key: "notes"})}
        />

    </FormControl>

    {<>
      <FormControl fullWidth sx={{m:2}}>
        <FormControlLabel
          disabled={!canBuyTokens}
          control={
            <Switch
              checked={buyingTokens}
              onChange={(event) => setBuyingTokens(event.target.checked)}/>
          }
          label="Tokens" />
      </FormControl>

      {buyingTokens && <FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Token Quantity"
          value={get(formData, "token_quantity", '')}
          inputProps={{ inputMode: 'numeric', pattern: '[0-9]*' }}
          type="number"
          pattern='[0-9]*'
          onChange={onChange({formData, setFormData, key: "token_quantity"})}
          />
      </FormControl> }
    </>}

    <FormControl fullWidth sx={{m: 2}}>
      <Button onClick={save(formData)}>Save</Button>
    </FormControl>
  </Box>
}