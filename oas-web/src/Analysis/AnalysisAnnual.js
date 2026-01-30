import { useEffect } from 'react';
import { useState } from '../utils/useState';
import { useOutletContext } from "react-router-dom";
import { get } from 'lodash'
import { Box, FormControl, responsiveFontSizes, TextField } from "@mui/material"
import moment from 'moment';
import { AnnualIncome } from './Annual/Income';
import { gql, useQuery } from '@apollo/client';
import { TransactionTags } from '../Money/TransactionTags';
import { AnnualReceivables } from './Annual/Receivables';
import { AnnualExpenses } from './Annual/Expenses';
import { AnnualLiabilities } from './Annual/Liabilities';
import { AnnualBalance } from './Annual/Balance'

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
          tagged {
            tag_names,
            amount
          }
        },
        annual_receivables {
          tokens,
          credits,
          total
        },
        annual_expenses {
          total,
          tagged {
            tag_names,
            amount
          }
        },
        annual_liabilities {
          credits,
          total
        },
        annual_balance
      },
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

    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 2, mt: 2 }}>
      <AnnualIncome data={data?.analysis_annual?.annual_income} />
      <AnnualReceivables data={data?.analysis_annual.annual_receivables} />
      <AnnualExpenses data={data?.analysis_annual.annual_expenses} />
      <AnnualLiabilities data={data?.analysis_annual.annual_liabilities} />
      <AnnualBalance balance={data?.analysis_annual.annual_balance} />
    </Box>
  </Box>
}
