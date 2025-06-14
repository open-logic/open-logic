import yaml
from pathlib import Path
from fnmatch import fnmatch
from TopLevel import TopLevel

class YamlInterpreter:

    def __init__(self, yaml_file_path):
        # Parse the YAML file
        self.data = self._parse_base_yaml(yaml_file_path)

        # Match files
        base_path = Path(yaml_file_path).parent.resolve()
        print(f"Base path: {base_path}")
        include_patterns = self.data["files"]["include"]
        exclude_patterns = self.data["files"]["exclude"]
        self.files =  self._match_files(base_path, include_patterns, exclude_patterns)

    def _parse_base_yaml(self, file_path):
        """
        Parses the base.yml file and returns its structured content.
        """
        with open(file_path, 'r') as file:
            data = yaml.safe_load(file)

        # Validate and process the "files" section
        files = data.get("files", {})
        include_patterns = files.get("include", [])
        exclude_patterns = files.get("exclude", [])

        # Validate and process the "entities" section
        entities = data.get("entities", [])
        parsed_entities = []
        for entity in entities:
            entity_name = entity.get("entity_name")
            fixed_generics = entity.get("fixed_generics", {})
            configurations = entity.get("configurations", [])
            tool_generics = entity.get("tool_generics", {})

            # Process configurations
            parsed_configurations = []
            for config in configurations:
                config_name = config.get("name")
                generics = config.get("generics", {})
                omitted_ports = config.get("omitted_ports", [])
                in_reduce = config.get("in_reduce", {})
                out_reduce = config.get("out_reduce", {})
                parsed_configurations.append({
                    "name": config_name,
                    "generics": generics,
                    "omitted_ports": omitted_ports,
                    "in_reduce": in_reduce,
                    "out_reduce": out_reduce
                })

            # Add parsed entity
            parsed_entities.append({
                "entity_name": entity_name,
                "fixed_generics": fixed_generics,
                "configurations": parsed_configurations,
                "tool_generics": tool_generics
            })

        return {
            "files": {
                "include": include_patterns,
                "exclude": exclude_patterns
            },
            "entities": parsed_entities,
        }


    def _match_files(self, base_path, include_patterns, exclude_patterns):
        """
        Matches files based on include and exclude patterns relative to the base path.
        """
        base_path = Path(base_path)
        matched_files = []

        for pattern in include_patterns:
            for file in base_path.glob(pattern):
                abs_path = file.absolute().resolve()
                # Check if the file matches any exclude pattern
                if not any(fnmatch(str(abs_path), exclude) for exclude in exclude_patterns):
                    matched_files.append(abs_path)

        return matched_files
    
    def get_top_levels(self):
        """
        Returns a list of top-level entities from the parsed YAML data.
        """
        top_levels = []
        for entity in self.data["entities"]:
            top = TopLevel(entity["entity_name"])
            # Add fixed generics
            top.add_fix_generics(entity["fixed_generics"])
            # Add tool generics
            for tool, generics in entity["tool_generics"].items():
                top.add_tool_generics(tool, generics)
            # Add configurations
            if not entity["configurations"]:
                # If no configurations, add a default one
                top.add_config("Default", {})
            else:
                for config in entity["configurations"]:
                    top.add_config(config["name"], config["generics"], config["omitted_ports"], config["in_reduce"], config["out_reduce"])
            top_levels.append(top)
        return top_levels
