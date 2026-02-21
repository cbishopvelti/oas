import { gql, useQuery } from '@apollo/client';
import { TextField } from '@mui/material';
import Autocomplete, { createFilterOptions } from '@mui/material/Autocomplete';
import { get } from 'lodash';

const filter = createFilterOptions()


export const VenueFilter = ({
  formData,
  setFormData
}) => {

  const { data, refetch } = useQuery(gql`
    query {
      training_wheres {
        id,
        name
      }
    }
  `)

  return <Autocomplete
    id="venueFilter"
    value={get(formData, "venues", []) || []}
    options={get(data, "training_wheres", []).map(({name, id}) => ({label: name, id, name}))}
    multiple
    freeSolo
    selectOnFocus
    clearOnBlur
    handleHomeEndKeys
    renderInput={(params) => <TextField {...params} label="Venues" />}
    getOptionLabel={(option) => {
      // Value selected with enter, right from the input
      if (typeof option === 'string') {
        return option;
      }
      // Regular option
      return option.label || option.name;
    }}
    onChange={(event, newValue) => {
      setFormData({
        ...formData,
        venues: newValue.map(({id, name}) => ({id, name}))
      })
    }}
  />

}
