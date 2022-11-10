import { gql, useQuery } from '@apollo/client';
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  FormControlLabel,
  Switch,
  FormControl,
  Box
} from '@mui/material';
import { get } from 'lodash';
import { Link, useParams, useOutletContext } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { MembersDisplay } from './MembersDisplay';


export const Members = () => {
  const { setTitle } = useOutletContext();
  setTitle("Members");
  const [filterData, setFilterData] = useState({})

  let { data: members, loading, refetch } = useQuery(gql`query ($show_all: Boolean) {
    members (show_all: $show_all) {
      id,
      name,
      email,
      tokens
    }
  }`, {
    variables: {
      show_all: filterData.show_all
    }
  });
  members = get(members, "members", []) || []
  useEffect(() => {
    refetch()
  }, [filterData])

  return <div>
    <Box>
      <FormControl sx={{m:2}}>
        <FormControlLabel
            control={
              <Switch 
                checked={get(filterData, 'show_all', false) || false}
                onChange={(event) => setFilterData({...filterData, show_all: event.target.checked})}/>
            }
            label="Show all" />
      </FormControl>
    </Box>
    <MembersDisplay members={members} />
  </div>
}
