import { useEffect } from 'react';
import { useState } from '../utils/useState';
import { Box, Button, FormControl, TextField, Container} from '@mui/material'
import moment from 'moment';
import { get } from 'lodash'
import { useQuery, gql } from '@apollo/client';
import { useOutletContext } from 'react-router-dom'

const onChange = ({formData, setFormData, key}) => (event) => {
    
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const Analysis = () => {
  const { setTitle } = useOutletContext();
  
  const [filterData, setFilterData ] = useState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD")
  }, { id: 'Analysis'});

  const {data, refetch} = useQuery(gql`
    query ($from: String!, $to: String!) {
      analysis (from: $from, to: $to) {
        transactions_income,
        transactions_outgoing,
        transactions_difference,
        unused_tokens,
        unused_tokens_amount,
        transactions_ballance
      }
    }
  `, {
    variables: filterData
  });
  useEffect(() => {
    setTitle("Analysis");
    refetch();
  }, [filterData])

  return <div>
    <Box sx={{display: 'flex', flexWrap: 'wrap',  backgroundColor: (theme) => theme.palette.grey[100]}}>
      <Container maxWidth="lg" sx={{ m: 2, p: 2, backgroundColor: 'white' }}>
        <Box sx={{display: 'flex', gap: 2}}>
          <FormControl sx={{ minWidth: 256}}>
            <TextField
              required
              id="from"
              label="From"
              type="date"
              value={get(filterData, "from")}
              onChange={onChange({formData: filterData, setFormData: setFilterData, key: "from"})}
              InputLabelProps={{
                shrink: true,
              }}
            />
          </FormControl>
          <FormControl sx={{ minWidth: 256}}>
            <TextField
              required
              id="to"
              label="To"
              type="date"
              value={get(filterData, "to")}
              onChange={onChange({formData: filterData, setFormData: setFilterData, key: "to"})}
              InputLabelProps={{
                shrink: true,
              }}
            />
          </FormControl>
        </Box>
        
        <Box>
          <Box sx={{width: '100%'}}>
            <h3>Income (GBP):</h3>
            <div>{get(data, 'analysis.transactions_income', 'Loading')}</div>
          </Box>
          <Box sx={{width: '100%'}}>
            <h3>Outgoing (GBP):</h3>
            <div>{get(data, 'analysis.transactions_outgoing', 'Loading')}</div>
          </Box>
          <Box sx={{width: '100%'}}>
            <h3>Difference (GBP):</h3>
            <div>{get(data, 'analysis.transactions_difference', 'Loading')}</div>
          </Box>
        </Box>
      </Container>

      <Container sx={{backgroundColor: 'white', p: 2, m: 2, mt: 0, pt: 0}}>
        <h2>Current State</h2>

        <Box sx={{width: '100%'}}>
          <h3>Total unused tokens:</h3>
          <div>{get(data, 'analysis.unused_tokens', 'Loading')}</div>
        </Box>

        <Box sx={{width: '100%'}}>
          <h3>Total unused tokens amount (GBP):</h3>
          <div>{get(data, 'analysis.unused_tokens_amount', 'Loading')}</div>
        </Box>

        <Box sx={{width: '100%'}}>
          <h3>Ballance (GBP):</h3>
          <div>{get(data, 'analysis.transactions_ballance', 'Loading')}</div>
        </Box>
      </Container>
    </Box>
  </div>
}