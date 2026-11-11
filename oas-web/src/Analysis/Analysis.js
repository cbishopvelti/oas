import { useEffect } from 'react';
import { useState } from '../utils/useState';
import { Box, Button, FormControl, TextField, Container} from '@mui/material'
import moment from 'moment';
import { get, round } from 'lodash'
import { useQuery, gql } from '@apollo/client';
import { useOutletContext } from 'react-router-dom'
import { formatMoney } from '../utils/money';

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
        transactions_ballance,
        credit,
        debt
      }
      config_config {
        id
        currency
      }
    }
  `, {
    variables: filterData
  });
  const currency = get(data, 'config_config.currency');
  const money = (key) => formatMoney(get(data, `analysis.${key}`), currency);

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
            <h3>Income:</h3>
            <div>{money('transactions_income')}</div>
          </Box>
          <Box sx={{width: '100%'}}>
            <h3>Outgoing:</h3>
            <div>{money('transactions_outgoing')}</div>
          </Box>
          <Box sx={{width: '100%'}}>
            <h3>Difference:</h3>
            <div>{money('transactions_difference')}</div>
          </Box>
        </Box>
      </Container>

      <Container sx={{backgroundColor: 'white', p: 2, m: 2, mt: 0, pt: 0}}>
        <h2>Current State</h2>

        <Box sx={{width: '100%'}}>
          <h3>Credits</h3>
          <div>{data ? formatMoney(get(data, 'analysis.credit') || 0, currency) : ''}</div>
        </Box>
        <Box sx={{width: '100%'}}>
          <h3>Debt</h3>
          <div>{data ? formatMoney(get(data, 'analysis.debt') || 0, currency) : ''}</div>
        </Box>

        <Box sx={{width: '100%'}}>
          <h3>Total unused tokens:</h3>
          <div>{get(data, 'analysis.unused_tokens') && round(get(data, 'analysis.unused_tokens'), 2)}</div>
        </Box>

        <Box sx={{width: '100%'}}>
          <h3>Total unused tokens amount:</h3>
          <div>{money('unused_tokens_amount')}</div>
        </Box>

        <Box sx={{width: '100%'}}>
          <h3>Balance:</h3>
          <div>{money('transactions_ballance')}</div>
        </Box>
      </Container>
    </Box>
  </div>
}
