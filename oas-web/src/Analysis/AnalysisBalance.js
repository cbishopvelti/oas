import { useQuery, gql } from "@apollo/client"
import { FormControl, Box, TextField } from "@mui/material"
import { useState } from "../utils/useState"
import moment from 'moment';
import { get } from 'lodash'
import Chart from "react-apexcharts";
import { useEffect } from "react";


const onChange = ({formData, setFormData, key, required}) => (event) => {
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const AnalysisBalance = () => {
  const [filterData, setFilterData] = useState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD")
  }, {id : 'Analysis'});

  const { data, refetch } = useQuery(gql`
    query($from: String!, $to: String!) {
      analysis_balance(to: $to, from: $from) {
        balance {
          x,
          y
        },
        outstanding_tokens {
          x,
          y
        },
        outstanding_attendance {
          x,
          y
        }
      }
    }
  `, {
    variables: {
      ...filterData
    },
    skip: !filterData.to || !filterData.from
  });

  useEffect(() => {
    refetch();
  }, [filterData])

  useEffect(() => {
  }, [data]);

  const series = [
    {
      name: 'Balance',
      data: get(data, 'analysis_balance.balance', []),
      color: '#7FFF00'
    },
    {
      name: "Outstanding Tokens",
      data: get(data, 'analysis_balance.outstanding_tokens', []),
      color: '#800080'
    },
    {
      name: "Outstanding Attendance",
      data: get(data, 'analysis_balance.outstanding_attendance', []),
      color: '#FF0000'
    }
  ]

  const options = {
    chart: {
      id: 'basic-bar'
    },
    xaxis: {
      type: 'datetime'
    },
    stroke: {
      curve: 'stepline',
      width: 2
    }
  }

  return <>
    <Box sx={{display: 'flex', gap: 2, m: 2, alignItems: 'center'}}>
      <FormControl sx={{ minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "from", '')}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "from", required: true})}
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
          value={get(filterData, "to", '')}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "to", required: true})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
    </Box>
    <Box sx={{m:2}}>
      <Chart
        options={options}
        series={series}
        type={'line'}
        height={512}
      />
    </Box>
  </>
}