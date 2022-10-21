import {useEffect, useState} from 'react';
import { Box, Button, FormControl, TextField} from '@mui/material'
import moment from 'moment';
import { get } from 'lodash'
import { useQuery, gql } from '@apollo/client';

const onChange = ({formData, setFormData, key}) => (event) => {
    
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const Analysis = () => {
  const [filterData, setFilterData ] = useState({
    from: moment().subtract(6, 'month').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD")
  });

  const {data, refetch} = useQuery(gql`
    query ($from: String!, $to: String!) {
      analysis (from: $from, to: $to) {
        transactions_income,
        transactions_outgoing,
        unused_tokens,
        unused_tokens_amount
      }
    }
  `, {
    variables: filterData
  });
  useEffect(() => {
    refetch();
  }, [filterData])

  return <div>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "from")}
          onChange={onChange({filterData, setFilterData, key: "from"})}
        />
      </FormControl>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "to")}
          onChange={onChange({filterData, setFilterData, key: "from"})}
        />
      </FormControl>
      <Button>Apply Filter</Button>
    </Box>

    <Box sx={{display: 'flex', flexWrap: 'wrap', m: 2}}>
      <Box sx={{width: '100%'}}>
        <h3>Income (GBP):</h3>
        <div>{get(data, 'analysis.transactions_income', 'Loading')}</div>
      </Box>
      <Box sx={{width: '100%'}}>
        <h3>Outgoing (GBP):</h3>
        <div>{get(data, 'analysis.transactions_outgoing', 'Loading')}</div>
      </Box>
      
      <h2>Current State (on 'to')</h2>

      <Box sx={{width: '100%'}}>
        <h3>Total unused tokens</h3>
        <div>{get(data, 'analysis.unused_tokens', 'Loading')}</div>
      </Box>

      <Box sx={{width: '100%'}}>
        <h3>Total unused tokens amount (GBP)</h3>
        <div>{get(data, 'analysis.unused_tokens_amount', 'Loading')}</div>
      </Box>
    </Box>
  </div>
}