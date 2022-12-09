import { useEffect } from "react";
import Chart from "react-apexcharts";
import { Box } from '@mui/material';
import moment from 'moment';
import {useQuery, gql} from '@apollo/client';
import { useState } from "../utils/useState";
import { TrainingsFilter } from "../Training/TrainingsFilter";
import { get, map, chain } from 'lodash';
import { useOutletContext } from "react-router-dom";

export const AnalysisAttendance = () => {
  const { setTitle } = useOutletContext();

  const [filterData, setFilterData] = useState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD")
  }, {id: 'AnalysisAttendance'});

  const {data, refetch } = useQuery(gql`
    query ($from: String!, $to: String!, $training_where: [TrainingWhereArg]) {
      trainings(from: $from, to: $to, training_where: $training_where) {
        id
        training_where {
          id,
          name
        },
        when,
        attendance
      }
    }
  `, {
    variables: filterData
  })

  useEffect(() => {
    let attendance = chain(data)
      .get(['trainings'], [])
      .sumBy('attendance')
      .value()
    let average = chain(data)
      .get(['trainings'], [])
      .meanBy('attendance')
      .round(1)
      .value()
    setTitle(`Analysis Attendance: ${attendance}, Average: ${average}`);
  }, [data])
  useEffect(() => {
    refetch()
  }, [filterData])


  const series = chain(data)
      .get('trainings', [])
      .groupBy(({training_where}) => {
        return training_where.name;
      })
      .map((group, key) => {
        console.log("002", group, key)
        return {
          name: key,
          data: map(group, (item) => ({
            x: item.when,
            y: item.attendance
          }))
        }
      }, {})
      .value()

  const options = {
    chart: {
      id: 'basic-bar'
    },
    xaxis: {
      type: 'datetime'
    }
  }

  return <>
    <TrainingsFilter 
      filterData={filterData}
      setFilterData={setFilterData}
    />
    <Box sx={{m:2}}>
      <Chart
        options={options}
        series={series}
        type={'bar'}
        height={512}
      />
    </Box>
  </>
}