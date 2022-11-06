import { useEffect, useState } from 'react'
import { omit, get } from 'lodash'
import { FormControl, FormControlLabel, Switch, TextField, Box, Button } from '@mui/material';
import { gql, useMutation } from '@apollo/client';

const onChange = ({formData, setFormData, key}) => (event) => {
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const TransactionAddToken = ({
  transaction_id,
  member_id,
  refetch
}) => {
  const [formData, setFormData] = useState({});

  useEffect(() => {
    setFormData({
      token_quantity: 1,
      token_value: 4.5
    })
  }, [transaction_id, member_id])

  const [mutate] = useMutation(gql`
    mutation ($member_id: Int!, $transaction_id: Int!, $amount: Int!, $value: Float!) {
      add_tokens(member_id: $member_id, transaction_id: $transaction_id, amount: $amount, value: $value) {
        amount
      }
    }
  `)

  const addTokensClick = ({transaction_id, member_id, formData}) => () => {
    mutate({
      variables: {
        transaction_id: transaction_id,
        member_id: member_id,
        amount: parseInt(formData.token_quantity),
        value: formData.token_value
      }
    })
    setFormData({})
    refetch()
  }

  return <Box sx={{display: 'flex', flexWrap: 'wrap', alignItems: "center"}}>
      <FormControl sx={{m:2, minWidth: 256}}>
        <TextField
          label="Token Quantity"
          value={get(formData, "token_quantity", '')}
          inputProps={{ inputMode: 'numeric', pattern: '[0-9]*' }}
          type="number"
          pattern='[0-9]*'
          onChange={onChange({formData, setFormData, key: "token_quantity"})}
          />
      </FormControl>
      <FormControl sx={{m:2, minWidth: 256}}>
        <TextField
          label="Token Value"
          value={get(formData, "token_value", '')}
          type="number"
          onChange={onChange({formData, setFormData, key: "token_value"})}
          />
      </FormControl>
      <FormControl sx={{m: 2}}>
        <Button onClick={addTokensClick({transaction_id, member_id, formData})}>Add</Button>
      </FormControl>
  </Box>
}

export const TransactionNewToken = ({
  formData,
  setFormData,
  id
}) => {
  

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
      setFormData(omit(formData, 'token_quantity', 'token_value'))
    }
  }, [canBuyTokens])
  useEffect(() => {
    if (!buyingTokens) {
      setFormData(omit(formData, ['token_quantity', 'token_value']))
    }
  }, [buyingTokens])

  return <>
    {!id && <>
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

      {buyingTokens && <><FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Token Quantity"
          value={get(formData, "token_quantity", '')}
          inputProps={{ inputMode: 'numeric', pattern: '[0-9]*' }}
          type="number"
          pattern='[0-9]*'
          onChange={(event) => {
            const tokenQuantity = event.target.value;
            let tokenValue = null;
            if (get(formData, "amount") ) {
              tokenValue = get(formData, "amount") / tokenQuantity;
            } else if (!get(formData, "token_vaule")) {
              tokenValue = 4.5
            }
            setFormData({
              ...formData, 
              token_quantity: tokenQuantity,
              ...(tokenValue ? {token_value: tokenValue} : {})
            })
          }}
          />
      </FormControl>
      <FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Token Value"
          value={get(formData, "token_value", '')}
          type="number"
          pattern='[0-9]*'
          onChange={onChange({formData, setFormData, key: "token_value"})}
          />
      </FormControl>
      </> }
    </>}
  </>
}

