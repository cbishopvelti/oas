import { useEffect } from 'react';
import { useState } from '../utils/useState';
import { useOutletContext } from "react-router-dom";
import { get } from 'lodash'
import { Box, FormControl, responsiveFontSizes, TextField } from "@mui/material"
import moment from 'moment';
import { AnnualIncome } from './Annual/Income';
import { gql, useQuery } from '@apollo/client';
import { TransactionTags } from '../Money/TransactionTags';

const onChange = ({formData, setFormData, key}) => (event) => {
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const AnalysisAnnual = () => {
  const { setTitle } = useOutletContext();
  const [filterData, setFilterData ] = useState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD")
  }, { id: 'Analysis'});

  useEffect(() => {
    setTitle("Annual Accounts")
  })

  const { data, refetch } = useQuery(gql`
    query ($from: String!, $to: String!, $transaction_tags: [TransactionTagArg]) {
      analysis_annual(from: $from, to: $to, transaction_tags: $transaction_tags) {
        annual_income {
          total,
          tokens,
          credit
        }
      }
    }
  `, {
    variables: filterData
  })
  useEffect(() => {
    refetch()
  }, [filterData])


  return <Box sx={{ p: 2, backgroundColor: (theme) => theme.palette.grey[100] }}>
    <Box sx={{display: 'flex', gap:2}}>
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
      <FormControl sx={{minWidth: 256}}>
        <TransactionTags formData={filterData} setFormData={setFilterData} filterMode={true} />
      </FormControl>
    </Box>

    <Box sx={{ display: 'flex', flexWrap: 'wrap' }}>
      <AnnualIncome data={data?.analysis_annual?.annual_income}/>
    </Box>
  </Box>
}
