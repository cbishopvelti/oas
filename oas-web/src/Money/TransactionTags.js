import { gql, useMutation, useQuery } from "@apollo/client";
import { Autocomplete, TextField } from "@mui/material";
import { get, includes, set, filter as lodashFilter, differenceWith, differenceBy, pick, map, uniqBy } from 'lodash'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { useEffect } from "react";

const filter = createFilterOptions();


export const TransactionTags = ({
  transactionTags = [],
  setTransactionTags = () => {},
  formData, 
  setFormData,
  filterMode
}) => {

  const {data, refetch } = useQuery(gql`
    query {
      transaction_tags {
        id,
        name
      }
    }
  `)
  let transaction_tags = uniqBy([...get(data, 'transaction_tags', []), ...transactionTags ], 'name')
  useEffect(() => {
    refetch()
  }, [formData.saveCount])

  return <Autocomplete
    id="transactionTags"
    value={get(formData, "transaction_tags") || (!transaction_tags.length && transaction_tags) || []}
    options={(transaction_tags).map(({name, id}) => ({ label: name, id, name }))}
    renderInput={(params) => <TextField {...params} label="Tags" />}
    multiple
    freeSolo={!filterMode}
    selectOnFocus
    clearOnBlur
    handleHomeEndKeys
    getOptionLabel={(option) => {
      // Value selected with enter, right from the input
      if (typeof option === 'string') {
        return option;
      }
      // Regular option
      return option.label || option.name;
    }}
    filterOptions={(options, params, b, c) => {
      let filtered = filter(options, params, b, c);
      const { inputValue } = params;

      const isExisting = options.some((option) => inputValue === option.name);
      if (inputValue !== '' && !isExisting && !filterMode) {
        filtered.push({
          name: inputValue,
          label: `Create "${inputValue}"`,
        });
      }

      // Only allow unique options
      filtered = differenceBy(filtered, formData.transaction_tags, "name")

      return filtered;
    }}
    onChange={async (event, newValue, a, b, c, d) => {
      setFormData({
        ...formData,
        transaction_tags: newValue.map(({id, name}) => ({id, name: name}))
      })
      setTransactionTags(uniqBy([
        ...newValue.filter(({id}) => !id)
          .map(({id, name}) => ({id, name})),
        ...transactionTags
      ], 'name'))
    }}
  />
}