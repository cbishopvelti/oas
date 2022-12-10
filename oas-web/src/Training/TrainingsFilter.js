import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  Box,
  FormControl,
  TextField,
  Button
} from '@mui/material';
import { get } from 'lodash';
import { TrainingTags } from "./TrainingTags";
import { TrainingWhereFilter } from "./TrainingWhereFilter";

const onChange = ({formData, setFormData, key}) => (event) => {   
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const TrainingsFilter = ({
  filterData,
  setFilterData
}) => {

  return <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "from", '')}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "from"})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TextField
          required
          id="to"
          label="To"
          type="date"
          value={get(filterData, "to", '')}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "to"})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
      {/* <FormControl sx={{m: 2, minWidth: 256}}>
        <TrainingTags 
          formData={filterData}
          setFormData={setFilterData}
          filterMode={true}
        />
      </FormControl> */}
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TrainingWhereFilter
          setFormData={setFilterData}
          formData={filterData}
        />
      </FormControl>
    </Box>
}
