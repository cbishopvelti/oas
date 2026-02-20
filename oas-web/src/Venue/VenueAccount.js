import { gql, useQuery } from "@apollo/client"
import { Box } from "@mui/material"
import { useParams, useOutletContext } from "react-router-dom";
import { get } from "lodash";
import { useEffect } from "react";

export const VenueAccount = () => {
  const { setTitle } = useOutletContext();

  let { training_where_id } = useParams();
  if (training_where_id) {
    training_where_id = parseInt(training_where_id);
  }

  const { data } = useQuery(gql`
    query($training_where_id: Int!) {
      training_where(id: $training_where_id){
        name,
        account_liability
      }
    }
  `, {
    variables: {
      training_where_id: training_where_id
    }
  })

  useEffect(() => {
    setTitle(`Liability to ${get(data, 'training_where.name', '')}: ${get(data, 'training_where.account_liability', '')}`);
  }, [data])

  return <Box sx={{ display: 'flex', gap: 2, m: 2, alignItems: 'center' }}>
  </Box>
}
