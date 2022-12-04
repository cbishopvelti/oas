import Chart from "react-apexcharts";
import { Box } from '@mui/material';
import moment from 'moment';


export const Attendance = () => {

  [
    {
      when: moment('2022-10-01'),
      attendance: 8,
      where: 'msc'
    }
  ]

  const options = {
    chart: {
      id: 'basic-bar'
    },
    xaxis: {
      categories: [1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999]
    }
  }
  const series = [
    {
      name: "series-1",
      data: [30, 40, 45, 50, 49, 60, 70, 91]
    }
  ]

  return <Box sx={{m:2}}>
    <Chart
      options={options}
      series={series}
      type={bar}
      height={512}
    />
  </Box>
}